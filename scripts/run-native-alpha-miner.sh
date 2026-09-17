#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[native-alpha-miner] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_helper="${ALPHA_MINER_PACKAGE_HELPER:-${script_dir}/alpha-miner-package.sh}"
[[ -f "$package_helper" ]] || die "package helper not found: ${package_helper}"
# shellcheck source=alpha-miner-package.sh
source "$package_helper"

version="${ALPHA_MINER_VERSION:-1.9.6}"
linux_asset="${ALPHA_MINER_LINUX_ASSET:-auto}"
base_url="${ALPHA_MINER_BASE_URL:-auto}"
package_sha256="${ALPHA_MINER_SHA256:-auto}"
install_dir="${ALPHA_MINER_DIR:-$HOME/.local/bin}"
miner_path="${install_dir}/alpha-miner"
runtime_dir="${ALPHA_MINER_RUNTIME_DIR:-${install_dir}/alpha-miner-runtime}"
version_marker="${ALPHA_MINER_VERSION_FILE:-${install_dir}/alpha-miner.version}"

reject_protected_override_controls() {
  [[ -z "${PEARL_XP+x}" ]] || die "PEARL_XP is rejected by Alpha Miner ${version}; remove rank/GEMM override environment variables"
  [[ -z "${PEARL_FORCE_BACKEND:-}" ]] || die "PEARL_FORCE_BACKEND is rejected by Alpha Miner ${version}; remove backend overrides"

  local env_name arg
  while IFS='=' read -r env_name _; do
    case "$env_name" in
      PEARL_XP_*|PEARL_XK_*)
        die "${env_name} is rejected by Alpha Miner ${version}; remove rank/GEMM override environment variables"
        ;;
    esac
  done < <(env)

  for arg in "$@"; do
    case "$arg" in
      --gemm|--gemm=*|--rank|--rank=*|--legacy-gemm|--legacy-gemm=*|--force-backend|--force-backend=*)
        die "${arg} is rejected by Alpha Miner ${version}; remove manual rank/GEMM/backend arguments"
        ;;
    esac
  done
}

reject_protected_override_controls "$@"

address="${PEARL_ADDRESS:-}"
[[ -n "$address" ]] || die "PEARL_ADDRESS is required, for example prl1..."
[[ "$address" == prl1* ]] || die "PEARL_ADDRESS must look like a Pearl mainnet address starting with prl1"

if [[ -n "${PEARL_MDL_ADDRESS:-}" ]]; then
  [[ "${PEARL_MDL_ADDRESS}" == mdl1* ]] || die "PEARL_MDL_ADDRESS must look like an MDL address starting with mdl1"
  [[ "$address" != *+* ]] || die "Use either PEARL_ADDRESS=prl1...+mdl1... or PEARL_MDL_ADDRESS=mdl1..., not both"
  address="${address}+${PEARL_MDL_ADDRESS}"
fi

worker="${PEARL_WORKER:-$(hostname)-pearl}"
worker="$(printf '%s' "$worker" | tr -cs 'A-Za-z0-9_.-' '-')"
worker="${worker#.}"
worker="${worker%-}"
[[ -n "$worker" ]] || worker="$(hostname)-pearl"

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

password="${PEARL_PASSWORD:-x}"
if [[ -n "${PEARL_DIFFICULTY:-}" ]]; then
  [[ "${PEARL_DIFFICULTY}" =~ ^[0-9]+$ ]] || die "PEARL_DIFFICULTY must be an integer"
  password="x;d=${PEARL_DIFFICULTY}"
fi

installed_version=""
if [[ -f "$version_marker" ]]; then
  installed_version="$(<"$version_marker")"
fi

if [[ ! -x "$miner_path" || "$installed_version" != "$version" || "${ALPHA_MINER_FORCE_DOWNLOAD:-}" =~ ^(1|true|TRUE|yes|YES)$ ]]; then
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"
  command -v tar >/dev/null 2>&1 || die "tar is required"
  mkdir -p "$install_dir"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  alpha_miner_resolve_package "$version" "$linux_asset" "$base_url" "$package_sha256" || die "could not resolve alpha-miner package"
  linux_asset="$ALPHA_MINER_RESOLVED_ASSET"

  log "Downloading alpha-miner ${version} asset ${linux_asset} from ${ALPHA_MINER_PACKAGE_URL}"
  curl -fsSL "$ALPHA_MINER_PACKAGE_URL" -o "${tmp_dir}/${linux_asset}"
  if [[ -n "$ALPHA_MINER_RESOLVED_SHA256" ]]; then
    (cd "$tmp_dir" && printf '%s  %s\n' "$ALPHA_MINER_RESOLVED_SHA256" "$linux_asset" | sha256sum -c -)
  else
    curl -fsSL "$ALPHA_MINER_CHECKSUM_URL" -o "${tmp_dir}/SHA256SUMS"
    (cd "$tmp_dir" && grep -E "[[:space:]]+${linux_asset}$" SHA256SUMS | sha256sum -c -)
  fi

  if [[ "$ALPHA_MINER_PACKAGE_LAYOUT" == "standalone" ]]; then
    install -m 0755 "${tmp_dir}/${linux_asset}" "$miner_path"
  else
    mkdir -p "${tmp_dir}/extract"
    if [[ "$ALPHA_MINER_PACKAGE_LAYOUT" == "self-extracting" ]]; then
      payload_line="$(awk '/^__ALPHAMINER_PAYLOAD_BELOW__$/{print NR + 1; exit}' "${tmp_dir}/${linux_asset}")"
      [[ -n "$payload_line" ]] || die "could not find embedded package payload"
      tail -n +"$payload_line" "${tmp_dir}/${linux_asset}" > "${tmp_dir}/payload.tar.gz"
      tar xzf "${tmp_dir}/payload.tar.gz" -C "${tmp_dir}/extract"
    else
      tar xzf "${tmp_dir}/${linux_asset}" -C "${tmp_dir}/extract"
    fi
    package_dir="$(find "${tmp_dir}/extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$package_dir" ]] || die "could not find extracted alpha-miner package directory"
    [[ -x "${package_dir}/alpha-miner" ]] || die "extracted package is missing executable alpha-miner launcher"
    if [[ "$ALPHA_MINER_PACKAGE_LAYOUT" == "legacy-tar" ]]; then
      [[ -f "${package_dir}/.alpha-miner-core" ]] || die "extracted package is missing .alpha-miner-core"
    else
      (cd "$package_dir" && sha256sum -c SHA256SUMS)
    fi
    rm -rf "${runtime_dir}.new"
    mkdir -p "${runtime_dir}.new"
    cp -a "${package_dir}/." "${runtime_dir}.new/"
    chmod 0755 "${runtime_dir}.new/alpha-miner"
    if [[ "$ALPHA_MINER_PACKAGE_LAYOUT" == "legacy-tar" ]]; then
      chmod 0755 "${runtime_dir}.new/.alpha-miner-core"
    fi
    rm -rf "$runtime_dir"
    mv "${runtime_dir}.new" "$runtime_dir"
    {
      printf '%s\n' '#!/usr/bin/env bash'
      printf 'exec %q "$@"\n' "${runtime_dir}/alpha-miner"
    } > "$miner_path"
    chmod 0755 "$miner_path"
  fi
  printf '%s\n' "$version" > "$version_marker"
fi

cli_style="${ALPHA_MINER_CLI_STYLE:-auto}"
if [[ "$cli_style" == "auto" ]]; then
  if [[ "$version" == "latest" ]]; then
    cli_style="current"
  elif [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    if (( 10#$major > 1 || (10#$major == 1 && 10#$minor > 9) || (10#$major == 1 && 10#$minor == 9 && 10#$patch >= 3) )); then
      cli_style="current"
    else
      cli_style="legacy"
    fi
  else
    die "Cannot infer CLI style from ALPHA_MINER_VERSION=${version}; set ALPHA_MINER_CLI_STYLE=current or legacy"
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

log "Starting alpha-miner version=${version} cli=${cli_style} worker=${miner_worker} pool=${pool_host}:${pool_port} devices=${PEARL_DEVICES:-all} difficulty=${PEARL_DIFFICULTY:-vardiff}"
exec "$miner_path" "${args[@]}" "$@"
