#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[gpu-presets] %s\n' "$*" >&2
}

is_true() {
  [[ "${1:-}" =~ ^(1|true|TRUE|yes|YES|on|ON)$ ]]
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

run_setting() {
  local description="$1"
  shift

  if is_true "${PEARL_GPU_PRESETS_DRY_RUN:-false}"; then
    log "DRY RUN: ${description}: $*"
    return 0
  fi

  if "$@"; then
    log "Applied ${description}"
  else
    log "WARN: failed ${description}: $*"
  fi
}

apply_nvidia_settings_attr() {
  local description="$1"
  shift

  if is_true "${PEARL_GPU_PRESETS_DRY_RUN:-false}"; then
    run_setting "$description" nvidia-settings "$@"
    return 0
  fi

  if ! command -v nvidia-settings >/dev/null 2>&1; then
    log "WARN: skipping ${description}; nvidia-settings is not installed"
    return 0
  fi

  if [[ -z "${DISPLAY:-}" ]]; then
    log "WARN: skipping ${description}; DISPLAY is not set"
    return 0
  fi

  run_setting "$description" nvidia-settings "$@"
}

enabled_by_env=false
if is_true "${PEARL_GPU_PRESETS_ENABLE:-false}" || [[ -n "${PEARL_GPU_PRESETS_URL:-}" ]]; then
  enabled_by_env=true
fi

if [[ "$enabled_by_env" != "true" ]]; then
  exit 0
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  log "WARN: nvidia-smi is not available; skipping GPU presets"
  exit 0
fi

preset_file="${PEARL_GPU_PRESETS_FILE:-/etc/pearl/gpu-presets.csv}"
preset_env_file="${PEARL_GPU_PRESETS_ENV_FILE:-/tmp/pearl-gpu-preset.env}"
algorithm="$(lower "$(trim "${PEARL_GPU_PRESETS_ALGORITHM:-pearlhash}")")"
timeout="${PEARL_GPU_PRESETS_TIMEOUT:-10}"

if [[ ! "$timeout" =~ ^[0-9]+$ ]]; then
  log "WARN: PEARL_GPU_PRESETS_TIMEOUT must be an integer; using 10 seconds"
  timeout=10
fi

tmp_file=""
cleanup() {
  if [[ -n "$tmp_file" ]]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

if [[ -n "${PEARL_GPU_PRESETS_URL:-}" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    log "WARN: curl is not available; cannot fetch ${PEARL_GPU_PRESETS_URL}; skipping GPU presets"
    exit 0
  fi

  tmp_file="$(mktemp)"
  log "Fetching GPU presets from ${PEARL_GPU_PRESETS_URL}"
  if curl -fsSL --max-time "$timeout" "${PEARL_GPU_PRESETS_URL}" -o "$tmp_file"; then
    preset_file="$tmp_file"
  else
    log "WARN: failed to fetch ${PEARL_GPU_PRESETS_URL}; skipping GPU presets"
    exit 0
  fi
fi

if [[ ! -f "$preset_file" ]]; then
  log "WARN: GPU preset file not found: ${preset_file}; skipping GPU presets"
  exit 0
fi

if [[ ! -s "$preset_file" ]]; then
  log "WARN: GPU preset file is empty: ${preset_file}; skipping GPU presets"
  exit 0
fi

log "Applying GPU presets from ${preset_file} for algorithm=${algorithm}"
rm -f "$preset_env_file"

gpu_lines="$(nvidia-smi --query-gpu=index,name --format=csv,noheader 2>/dev/null || true)"
if [[ -z "$gpu_lines" ]]; then
  log "WARN: no NVIDIA GPUs detected by nvidia-smi; skipping GPU presets"
  exit 0
fi

find_preset_for_gpu() {
  local gpu_name_lc="$1"
  local line enabled row_algorithm matcher pearl_difficulty power_limit_w lock_core_clock_mhz core_clock_offset_mhz lock_memory_clock_mhz memory_clock_offset_mhz fan_speed_pct delay_before_apply_s extra

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$(trim "$line")" ]] && continue
    [[ "$(lower "$(trim "$line")")" == enabled,algorithm,gpu_name_contains,* ]] && continue
    [[ "$(trim "$line")" == \#* ]] && continue

    IFS=',' read -r enabled row_algorithm matcher pearl_difficulty power_limit_w lock_core_clock_mhz core_clock_offset_mhz lock_memory_clock_mhz memory_clock_offset_mhz fan_speed_pct delay_before_apply_s extra <<<"$line"
    if [[ -n "${extra:-}" ]]; then
      log "WARN: skipping CSV row with too many fields: ${line}"
      continue
    fi

    enabled="$(lower "$(trim "${enabled:-}")")"
    row_algorithm="$(lower "$(trim "${row_algorithm:-}")")"
    matcher="$(lower "$(trim "${matcher:-}")")"

    [[ "$enabled" == "true" || "$enabled" == "1" || "$enabled" == "yes" ]] || continue
    [[ -z "$row_algorithm" || "$row_algorithm" == "$algorithm" ]] || continue
    [[ -n "$matcher" ]] || continue

    if [[ "$gpu_name_lc" == *"$matcher"* ]]; then
      printf '%s\n' "$line"
      return 0
    fi
  done <"$preset_file"

  return 1
}

while IFS=',' read -r gpu_index gpu_name || [[ -n "${gpu_index:-}" ]]; do
  gpu_index="$(trim "${gpu_index:-}")"
  gpu_name="$(trim "${gpu_name:-}")"
  [[ -n "$gpu_index" && -n "$gpu_name" ]] || continue

  preset_line="$(find_preset_for_gpu "$(lower "$gpu_name")" || true)"
  if [[ -z "$preset_line" ]]; then
    log "WARN: no matching preset for GPU ${gpu_index}: ${gpu_name}"
    continue
  fi

  IFS=',' read -r enabled row_algorithm matcher pearl_difficulty power_limit_w lock_core_clock_mhz core_clock_offset_mhz lock_memory_clock_mhz memory_clock_offset_mhz fan_speed_pct delay_before_apply_s <<<"$preset_line"

  matcher="$(trim "${matcher:-}")"
  pearl_difficulty="$(trim "${pearl_difficulty:-}")"
  power_limit_w="$(trim "${power_limit_w:-}")"
  lock_core_clock_mhz="$(trim "${lock_core_clock_mhz:-}")"
  core_clock_offset_mhz="$(trim "${core_clock_offset_mhz:-}")"
  lock_memory_clock_mhz="$(trim "${lock_memory_clock_mhz:-}")"
  memory_clock_offset_mhz="$(trim "${memory_clock_offset_mhz:-}")"
  fan_speed_pct="$(trim "${fan_speed_pct:-}")"
  delay_before_apply_s="$(trim "${delay_before_apply_s:-}")"

  log "GPU ${gpu_index}: ${gpu_name} matched preset '${matcher}'"

  if [[ -n "$pearl_difficulty" ]]; then
    if [[ "$pearl_difficulty" =~ ^[0-9]+$ ]]; then
      if [[ -z "${PEARL_DIFFICULTY:-}" && ! -f "$preset_env_file" ]]; then
        printf 'PEARL_PRESET_DIFFICULTY=%s\n' "$pearl_difficulty" >"$preset_env_file"
        log "Selected Pearl difficulty ${pearl_difficulty} from GPU ${gpu_index} preset"
      elif [[ -n "${PEARL_DIFFICULTY:-}" ]]; then
        log "Pearl difficulty ${pearl_difficulty} from preset ignored because PEARL_DIFFICULTY is already set"
      fi
    else
      log "WARN: invalid pearl_difficulty for GPU ${gpu_index}: ${pearl_difficulty}"
    fi
  fi

  if [[ -n "$delay_before_apply_s" ]]; then
    if [[ "$delay_before_apply_s" =~ ^[0-9]+$ ]]; then
      if is_true "${PEARL_GPU_PRESETS_DRY_RUN:-false}"; then
        log "DRY RUN: sleep ${delay_before_apply_s} before applying GPU ${gpu_index} preset"
      elif [[ "$delay_before_apply_s" -gt 0 ]]; then
        sleep "$delay_before_apply_s"
      fi
    else
      log "WARN: invalid delay_before_apply_s for GPU ${gpu_index}: ${delay_before_apply_s}"
    fi
  fi

  run_setting "GPU ${gpu_index} persistence mode" nvidia-smi -i "$gpu_index" -pm 1

  if [[ -n "$power_limit_w" ]]; then
    if [[ "$power_limit_w" =~ ^[0-9]+$ ]]; then
      run_setting "GPU ${gpu_index} power limit ${power_limit_w}W" nvidia-smi -i "$gpu_index" -pl "$power_limit_w"
    else
      log "WARN: invalid power_limit_w for GPU ${gpu_index}: ${power_limit_w}"
    fi
  fi

  if [[ -n "$lock_core_clock_mhz" ]]; then
    if [[ "$lock_core_clock_mhz" =~ ^[0-9]+$ ]]; then
      run_setting "GPU ${gpu_index} locked core clock ${lock_core_clock_mhz}MHz" nvidia-smi -i "$gpu_index" -lgc "${lock_core_clock_mhz},${lock_core_clock_mhz}"
    else
      log "WARN: invalid lock_core_clock_mhz for GPU ${gpu_index}: ${lock_core_clock_mhz}"
    fi
  fi

  if [[ -n "$lock_memory_clock_mhz" ]]; then
    if [[ "$lock_memory_clock_mhz" =~ ^[0-9]+$ ]]; then
      run_setting "GPU ${gpu_index} locked memory clock ${lock_memory_clock_mhz}MHz" nvidia-smi -i "$gpu_index" -lmc "${lock_memory_clock_mhz},${lock_memory_clock_mhz}"
    else
      log "WARN: invalid lock_memory_clock_mhz for GPU ${gpu_index}: ${lock_memory_clock_mhz}"
    fi
  fi

  if [[ -n "$core_clock_offset_mhz" ]]; then
    if [[ "$core_clock_offset_mhz" =~ ^-?[0-9]+$ ]]; then
      apply_nvidia_settings_attr "GPU ${gpu_index} core clock offset ${core_clock_offset_mhz}MHz" -a "[gpu:${gpu_index}]/GPUGraphicsClockOffset[3]=${core_clock_offset_mhz}"
    else
      log "WARN: invalid core_clock_offset_mhz for GPU ${gpu_index}: ${core_clock_offset_mhz}"
    fi
  fi

  if [[ -n "$memory_clock_offset_mhz" ]]; then
    if [[ "$memory_clock_offset_mhz" =~ ^-?[0-9]+$ ]]; then
      apply_nvidia_settings_attr "GPU ${gpu_index} memory clock offset ${memory_clock_offset_mhz}MHz" -a "[gpu:${gpu_index}]/GPUMemoryTransferRateOffset[3]=${memory_clock_offset_mhz}"
    else
      log "WARN: invalid memory_clock_offset_mhz for GPU ${gpu_index}: ${memory_clock_offset_mhz}"
    fi
  fi

  if [[ -n "$fan_speed_pct" ]]; then
    if [[ "$fan_speed_pct" =~ ^[0-9]+$ ]]; then
      apply_nvidia_settings_attr "GPU ${gpu_index} fan speed ${fan_speed_pct}%" -a "[gpu:${gpu_index}]/GPUFanControlState=1" -a "[fan:${gpu_index}]/GPUTargetFanSpeed=${fan_speed_pct}"
    else
      log "WARN: invalid fan_speed_pct for GPU ${gpu_index}: ${fan_speed_pct}"
    fi
  fi
done <<<"$gpu_lines"
