#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[native-alpha-miner] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

version="${ALPHA_MINER_VERSION:-1.8.6}"
install_dir="${ALPHA_MINER_DIR:-$HOME/.local/bin}"
miner_path="${install_dir}/alpha-miner"

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

pool="${PEARL_POOL:-${PEARL_POOL_URL:-}}"
if [[ -z "$pool" ]]; then
  pool_host="${PEARL_POOL_HOST:-us2.alphapool.tech}"
  pool_port="${PEARL_POOL_PORT:-5566}"
  [[ "$pool_host" != "pearl.alphapool.tech" ]] || die "Use a stratum host like us2.alphapool.tech, not pearl.alphapool.tech"
  pool="stratum+tcp://${pool_host}:${pool_port}"
fi
if [[ "$pool" != stratum+tcp://* ]]; then
  pool="stratum+tcp://${pool}"
fi
[[ "$pool" != *"pearl.alphapool.tech"* ]] || die "Use a stratum host like us2.alphapool.tech, not pearl.alphapool.tech"

status_interval="${PEARL_STATUS_INTERVAL:-60}"
[[ "$status_interval" =~ ^[0-9]+$ ]] || die "PEARL_STATUS_INTERVAL must be an integer"

password="${PEARL_PASSWORD:-x}"
if [[ -n "${PEARL_DIFFICULTY:-}" ]]; then
  [[ "${PEARL_DIFFICULTY}" =~ ^[0-9]+$ ]] || die "PEARL_DIFFICULTY must be an integer"
  password="x;d=${PEARL_DIFFICULTY}"
fi

if [[ ! -x "$miner_path" || "${ALPHA_MINER_FORCE_DOWNLOAD:-}" =~ ^(1|true|TRUE|yes|YES)$ ]]; then
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"
  mkdir -p "$install_dir"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  if [[ "$version" == "latest" ]]; then
    release_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/latest/download"
  else
    release_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/download/v${version}"
  fi

  log "Downloading alpha-miner ${version} from ${release_url}"
  curl -fsSL "${release_url}/alpha-miner" -o "${tmp_dir}/alpha-miner"
  curl -fsSL "${release_url}/SHA256SUMS" -o "${tmp_dir}/SHA256SUMS"
  (cd "$tmp_dir" && grep -E '[[:space:]]+alpha-miner$' SHA256SUMS | sha256sum -c -)
  install -m 0755 "${tmp_dir}/alpha-miner" "$miner_path"
fi

args=(
  --pool "$pool"
  --address "$address"
  --worker "$worker"
  --password "$password"
  --status-interval "$status_interval"
)

if [[ -n "${PEARL_DEVICES:-}" ]]; then
  args+=(--devices "$PEARL_DEVICES")
fi

if [[ -n "${PEARL_FORCE_BACKEND:-}" ]]; then
  args+=(--force-backend "$PEARL_FORCE_BACKEND")
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  log "Detected NVIDIA GPUs:"
  nvidia-smi --query-gpu=index,name,driver_version --format=csv,noheader || true
fi

if [[ "$address" == *+mdl1* ]]; then
  log "MDL merge-mining enabled via combined PRL+MDL address"
fi

log "Starting alpha-miner worker=${worker} pool=${pool} devices=${PEARL_DEVICES:-all} difficulty=${PEARL_DIFFICULTY:-vardiff}"
exec "$miner_path" "${args[@]}" "$@"
