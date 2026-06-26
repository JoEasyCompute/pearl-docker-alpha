#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[pearl-entrypoint] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

if [[ "${1:-}" == "bash" || "${1:-}" == "sh" || "${1:-}" == "alpha-miner" || "${1:-}" == /* ]]; then
  exec "$@"
fi

if [[ "${PEARL_LIST_DEVICES:-}" =~ ^(1|true|TRUE|yes|YES)$ ]]; then
  exec alpha-miner --list-devices
fi

address="${PEARL_ADDRESS:-}"
[[ -n "$address" ]] || die "PEARL_ADDRESS is required, for example prl1p..."
[[ "$address" == prl1p* ]] || die "PEARL_ADDRESS must look like a Pearl mainnet address starting with prl1p"

worker="${PEARL_WORKER:-${VAST_CONTAINERLABEL:-${HOSTNAME:-vast-rig}}}"
worker="$(printf '%s' "$worker" | tr -cs 'A-Za-z0-9_.-' '-')"
worker="${worker#.}"
worker="${worker%-}"
[[ -n "$worker" ]] || worker="vast-rig"

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

log "Starting alpha-miner worker=${worker} pool=${pool} devices=${PEARL_DEVICES:-all} difficulty=${PEARL_DIFFICULTY:-vardiff}"
exec alpha-miner "${args[@]}" "$@"
