#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[pearl-entrypoint] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

reject_protected_override_controls() {
  local miner_version="${ALPHA_MINER_VERSION:-current}"
  [[ -z "${PEARL_XP+x}" ]] || die "PEARL_XP is rejected by Alpha Miner ${miner_version}; remove rank/GEMM override environment variables"
  [[ -z "${PEARL_FORCE_BACKEND:-}" ]] || die "PEARL_FORCE_BACKEND is rejected by Alpha Miner ${miner_version}; remove backend overrides"

  local env_name arg
  while IFS='=' read -r env_name _; do
    case "$env_name" in
      PEARL_XP_*|PEARL_XK_*)
        die "${env_name} is rejected by Alpha Miner ${miner_version}; remove rank/GEMM override environment variables"
        ;;
    esac
  done < <(env)

  for arg in "$@"; do
    case "$arg" in
      --gemm|--gemm=*|--rank|--rank=*|--legacy-gemm|--legacy-gemm=*|--force-backend|--force-backend=*)
        die "${arg} is rejected by Alpha Miner ${miner_version}; remove manual rank/GEMM/backend arguments"
        ;;
    esac
  done
}

if [[ "${1:-}" == "bash" || "${1:-}" == "sh" || "${1:-}" == "alpha-miner" || "${1:-}" == /* ]]; then
  exec "$@"
fi

reject_protected_override_controls "$@"

if [[ "${PEARL_LIST_DEVICES:-}" =~ ^(1|true|TRUE|yes|YES)$ ]]; then
  command -v nvidia-smi >/dev/null 2>&1 || die "nvidia-smi is required to list devices"
  exec nvidia-smi --query-gpu=index,name,compute_cap --format=csv,noheader
fi

address="${PEARL_ADDRESS:-}"
[[ -n "$address" ]] || die "PEARL_ADDRESS is required, for example prl1..."
[[ "$address" == prl1* ]] || die "PEARL_ADDRESS must look like a Pearl mainnet address starting with prl1"

if [[ -n "${PEARL_MDL_ADDRESS:-}" ]]; then
  [[ "${PEARL_MDL_ADDRESS}" == mdl1* ]] || die "PEARL_MDL_ADDRESS must look like an MDL address starting with mdl1"
  [[ "$address" != *+* ]] || die "Use either PEARL_ADDRESS=prl1...+mdl1... or PEARL_MDL_ADDRESS=mdl1..., not both"
  address="${address}+${PEARL_MDL_ADDRESS}"
fi

worker="${PEARL_WORKER:-${VAST_CONTAINERLABEL:-${HOSTNAME:-vast-rig}}}"
worker="$(printf '%s' "$worker" | tr -cs 'A-Za-z0-9_.-' '-')"
worker="${worker#.}"
worker="${worker%-}"
[[ -n "$worker" ]] || worker="vast-rig"

pool_endpoint="${PEARL_POOL:-${PEARL_POOL_URL:-}}"
if [[ -z "$pool_endpoint" ]]; then
  pool_host="${PEARL_POOL_HOST:-us2.alphapool.tech}"
  pool_port="${PEARL_POOL_PORT:-5566}"
else
  pool_endpoint="${pool_endpoint#stratum+tcp://}"
  [[ "$pool_endpoint" == *:* ]] || die "PEARL_POOL must include a port, for example us2.alphapool.tech:5566"
  pool_host="${pool_endpoint%:*}"
  pool_port="${pool_endpoint##*:}"
fi
[[ "$pool_host" != "pearl.alphapool.tech" ]] || die "Use a stratum host like us2.alphapool.tech, not pearl.alphapool.tech"
[[ "$pool_port" =~ ^[0-9]+$ ]] || die "PEARL_POOL_PORT must be an integer"
(( 10#$pool_port >= 1 && 10#$pool_port <= 65535 )) || die "PEARL_POOL_PORT must be between 1 and 65535"

if command -v apply-gpu-presets >/dev/null 2>&1; then
  apply-gpu-presets || log "WARN: GPU preset preflight failed unexpectedly; continuing to miner"
else
  log "WARN: apply-gpu-presets helper is not installed; continuing to miner"
fi

gpu_preset_env_file="${PEARL_GPU_PRESETS_ENV_FILE:-/tmp/pearl-gpu-preset.env}"
if [[ -z "${PEARL_DIFFICULTY:-}" && -f "$gpu_preset_env_file" ]]; then
  # shellcheck disable=SC1090
  source "$gpu_preset_env_file"
  if [[ -n "${PEARL_PRESET_DIFFICULTY:-}" ]]; then
    if [[ "$PEARL_PRESET_DIFFICULTY" =~ ^[0-9]+$ ]]; then
      PEARL_DIFFICULTY="$PEARL_PRESET_DIFFICULTY"
      log "Using Pearl difficulty from GPU preset: ${PEARL_DIFFICULTY}"
    else
      log "WARN: ignoring invalid PEARL_PRESET_DIFFICULTY=${PEARL_PRESET_DIFFICULTY}"
    fi
  fi
fi

password="${PEARL_PASSWORD:-x}"
if [[ -n "${PEARL_DIFFICULTY:-}" ]]; then
  [[ "${PEARL_DIFFICULTY}" =~ ^[0-9]+$ ]] || die "PEARL_DIFFICULTY must be an integer"
  password="x;d=${PEARL_DIFFICULTY}"
fi

cli_style="${ALPHA_MINER_CLI_STYLE:-auto}"
if [[ "$cli_style" == "auto" ]]; then
  miner_version="${ALPHA_MINER_VERSION:-1.9.6}"
  if [[ "$miner_version" == "latest" ]]; then
    cli_style="current"
  elif [[ "$miner_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    if (( 10#$major > 1 || (10#$major == 1 && 10#$minor > 9) || (10#$major == 1 && 10#$minor == 9 && 10#$patch >= 3) )); then
      cli_style="current"
    else
      cli_style="legacy"
    fi
  else
    die "Cannot infer CLI style from ALPHA_MINER_VERSION=${miner_version}; set ALPHA_MINER_CLI_STYLE=current or legacy"
  fi
fi
[[ "$cli_style" == "current" || "$cli_style" == "legacy" ]] || die "ALPHA_MINER_CLI_STYLE must be auto, current, or legacy"

if [[ "$cli_style" == "current" ]]; then
  args=(
    --host "$pool_host"
    --port "$pool_port"
    --worker "${address}.${worker}"
    --password "$password"
  )
  if [[ -n "${PEARL_DEVICES:-}" ]]; then
    [[ "$PEARL_DEVICES" =~ ^[0-9]+(,[0-9]+)*$ ]] || die "PEARL_DEVICES must be a comma-separated list of GPU indexes"
    [[ -z "${CUDA_VISIBLE_DEVICES:-}" ]] || die "Set either PEARL_DEVICES or CUDA_VISIBLE_DEVICES, not both"
    export CUDA_VISIBLE_DEVICES="$PEARL_DEVICES"
  fi
  miner_worker="${address}.${worker}"
else
  status_interval="${PEARL_STATUS_INTERVAL:-60}"
  [[ "$status_interval" =~ ^[0-9]+$ ]] || die "PEARL_STATUS_INTERVAL must be an integer"
  args=(
    --pool "stratum+tcp://${pool_host}:${pool_port}"
    --address "$address"
    --worker "$worker"
    --password "$password"
    --status-interval "$status_interval"
  )
  if [[ -n "${PEARL_DEVICES:-}" ]]; then
    args+=(--devices "$PEARL_DEVICES")
  fi
  miner_worker="$worker"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  log "Detected NVIDIA GPUs:"
  nvidia-smi --query-gpu=index,name,driver_version --format=csv,noheader || true
fi

if [[ "$address" == *+mdl1* ]]; then
  log "MDL merge-mining enabled via combined PRL+MDL address"
fi

log "Starting alpha-miner version=${ALPHA_MINER_VERSION:-unknown} cli=${cli_style} worker=${miner_worker} pool=${pool_host}:${pool_port} devices=${PEARL_DEVICES:-all} difficulty=${PEARL_DIFFICULTY:-vardiff}"
exec alpha-miner "${args[@]}" "$@"
