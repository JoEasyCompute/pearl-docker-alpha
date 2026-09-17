#!/usr/bin/env bash
set -Eeuo pipefail

image="${PEARL_IMAGE:-pearl-miner:1.9.6}"
name="${PEARL_CONTAINER_NAME:-pearl-miner}"

die() {
  printf '[docker-runc-gpu] ERROR: %s\n' "$*" >&2
  exit 1
}

find_lib() {
  local lib="$1"
  ldconfig -p 2>/dev/null | awk -v lib="$lib" '$1 == lib { print $NF; exit }'
}

address="${PEARL_ADDRESS:-}"
[[ -n "$address" ]] || die "PEARL_ADDRESS is required"

if [[ -n "${PEARL_MDL_ADDRESS:-}" ]]; then
  [[ "${PEARL_MDL_ADDRESS}" == mdl1* ]] || die "PEARL_MDL_ADDRESS must look like an MDL address starting with mdl1"
  [[ "$address" != *+* ]] || die "Use either PEARL_ADDRESS=prl1...+mdl1... or PEARL_MDL_ADDRESS=mdl1..., not both"
fi

device_args=()
shopt -s nullglob
for dev in /dev/nvidia*; do
  device_args+=(--device "$dev:$dev")
done
shopt -u nullglob
[[ ${#device_args[@]} -gt 0 ]] || die "No /dev/nvidia* devices found"

mount_args=()
required_libs=(libcuda.so.1)
optional_libs=(
  libnvidia-ml.so.1
  libnvidia-cfg.so.1
  libnvidia-ptxjitcompiler.so.1
  libnvidia-fatbinaryloader.so.1
  libnvidia-nvvm.so.4
)

for lib in "${required_libs[@]}"; do
  lib_path="$(find_lib "$lib")"
  [[ -n "$lib_path" ]] || die "Could not locate $lib with ldconfig"
  lib_real="$(readlink -f "$lib_path")"
  mount_args+=(-v "${lib_real}:/usr/local/nvidia/lib64/${lib}:ro")
done

for lib in "${optional_libs[@]}"; do
  lib_path="$(find_lib "$lib" || true)"
  if [[ -n "$lib_path" ]]; then
    lib_real="$(readlink -f "$lib_path")"
    mount_args+=(-v "${lib_real}:/usr/local/nvidia/lib64/${lib}:ro")
  fi
done

docker rm -f "$name" >/dev/null 2>&1 || true

exec docker run -d --restart unless-stopped --runtime=runc \
  --name "$name" \
  "${device_args[@]}" \
  "${mount_args[@]}" \
  -e LD_LIBRARY_PATH=/usr/local/nvidia/lib64:/usr/local/cuda/lib64 \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  -e PEARL_ADDRESS="$PEARL_ADDRESS" \
  -e PEARL_MDL_ADDRESS="${PEARL_MDL_ADDRESS:-}" \
  -e PEARL_WORKER="${PEARL_WORKER:-$(hostname)-pearl}" \
  -e PEARL_POOL_HOST="${PEARL_POOL_HOST:-us2.alphapool.tech}" \
  -e PEARL_POOL_PORT="${PEARL_POOL_PORT:-5566}" \
  -e PEARL_DIFFICULTY="${PEARL_DIFFICULTY:-1048576}" \
  "$image"
