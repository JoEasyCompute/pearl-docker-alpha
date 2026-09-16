#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"

cat > "$tmp_dir/bin/apply-gpu-presets" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$tmp_dir/bin/alpha-miner" <<'EOF'
#!/usr/bin/env bash
printf 'CUDA_VISIBLE_DEVICES=%s\n' "${CUDA_VISIBLE_DEVICES:-}"
printf 'ARG=%s\n' "$@"
EOF

cat > "$tmp_dir/bin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
printf '0, NVIDIA GeForce RTX 5090, 12.0\n'
EOF

chmod 0755 "$tmp_dir/bin/apply-gpu-presets" "$tmp_dir/bin/alpha-miner" "$tmp_dir/bin/nvidia-smi"

run_entrypoint() {
  env \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    PEARL_ADDRESS="prl1ptestaddress" \
    PEARL_WORKER="test-rig" \
    PEARL_POOL_HOST="eu1.alphapool.tech" \
    PEARL_POOL_PORT="5566" \
    PEARL_DIFFICULTY="1048576" \
    "$@" \
    bash "$repo_dir/entrypoint.sh"
}

assert_line() {
  local expected="$1" output="$2"
  grep -Fqx -- "$expected" <<<"$output" || {
    printf 'missing expected line: %s\noutput:\n%s\n' "$expected" "$output" >&2
    return 1
  }
}

assert_no_line() {
  local unexpected="$1" output="$2"
  if grep -Fqx -- "$unexpected" <<<"$output"; then
    printf 'unexpected line: %s\noutput:\n%s\n' "$unexpected" "$output" >&2
    return 1
  fi
}

test_maps_environment_to_current_cli() {
  local output
  output="$(run_entrypoint 2>&1)"

  assert_line "ARG=--host" "$output"
  assert_line "ARG=eu1.alphapool.tech" "$output"
  assert_line "ARG=--port" "$output"
  assert_line "ARG=5566" "$output"
  assert_line "ARG=--worker" "$output"
  assert_line "ARG=prl1ptestaddress.test-rig" "$output"
  assert_line "ARG=--password" "$output"
  assert_line "ARG=x;d=1048576" "$output"
  assert_no_line "ARG=--pool" "$output"
  assert_no_line "ARG=--address" "$output"
  assert_no_line "ARG=--status-interval" "$output"
}

test_merge_mining_worker_identity() {
  local output
  output="$(run_entrypoint PEARL_MDL_ADDRESS="mdl1testaddress" 2>&1)"

  assert_line "ARG=prl1ptestaddress+mdl1testaddress.test-rig" "$output"
}

test_devices_limit_cuda_visibility() {
  local output
  output="$(run_entrypoint PEARL_DEVICES="1,3" 2>&1)"

  assert_line "CUDA_VISIBLE_DEVICES=1,3" "$output"
  assert_no_line "ARG=--devices" "$output"
  assert_no_line "ARG=--gpu" "$output"
}

test_lists_devices_without_removed_miner_option() {
  local output
  output="$(run_entrypoint PEARL_LIST_DEVICES=true 2>&1)"

  assert_line "0, NVIDIA GeForce RTX 5090, 12.0" "$output"
  assert_no_line "ARG=--list-devices" "$output"
}

test_preserves_legacy_cli_for_rollbacks() {
  local output
  output="$(run_entrypoint ALPHA_MINER_VERSION="1.9.1.02" PEARL_STATUS_INTERVAL="30" 2>&1)"

  assert_line "ARG=--pool" "$output"
  assert_line "ARG=stratum+tcp://eu1.alphapool.tech:5566" "$output"
  assert_line "ARG=--address" "$output"
  assert_line "ARG=prl1ptestaddress" "$output"
  assert_line "ARG=--worker" "$output"
  assert_line "ARG=test-rig" "$output"
  assert_line "ARG=--status-interval" "$output"
  assert_line "ARG=30" "$output"
}

test_maps_environment_to_current_cli
test_merge_mining_worker_identity
test_devices_limit_cuda_visibility
test_lists_devices_without_removed_miner_option
test_preserves_legacy_cli_for_rollbacks
printf 'entrypoint tests passed\n'
