# Pearl Miner Runtime 2026-07-06

Category: session-log
Tags: pearl, alpha-miner, mdl, gpu-presets, vast, docker

## Current Runtime

- Docker image defaults to AlphaMine `v1.8.6`, matching the upstream pre-release that adds native PRL+MDL merge-mining address support.
- `PEARL_ADDRESS` remains the required PRL wallet address and must start with `prl1`.
- `PEARL_MDL_ADDRESS` is optional. When set, the entrypoint passes `--address prl1...+mdl1...` to `alpha-miner`.
- If `PEARL_ADDRESS` already contains `+mdl1...`, `PEARL_MDL_ADDRESS` must not also be set.
- Upstream `v1.8.6` requires NVIDIA driver `580` or newer; Vast hosts with older drivers should use the previous stable miner path instead.

## GPU Preset Integration

- GPU presets are opt-in through `PEARL_GPU_PRESETS_ENABLE=true` or by setting `PEARL_GPU_PRESETS_URL`.
- Presets are loaded from a live CSV URL or local `PEARL_GPU_PRESETS_FILE`.
- CSV matching is first-match-wins using case-insensitive substring matching against `nvidia-smi --query-gpu=index,name --format=csv,noheader`.
- Docker applies only best-effort settings that are reliably available through `nvidia-smi`: persistence mode, power limit, locked core clock, and locked memory clock.
- Offset and fan settings are parsed and logged. They are applied only when `nvidia-settings` plus host/X access are available; otherwise the miner warns and continues.
- `pearl_difficulty` in the matching CSV row can supply `PEARL_DIFFICULTY` when the env var is unset. Explicit env vars always win over CSV values.
- Screenshot-derived RTX 5090 preset is stored in `examples/gpu-presets-5090-screenshot.csv`.

## Vast Deployment Notes

- Vast's Kaalia NVIDIA shim can fail container startup even when host `nvidia-smi` works.
- The repo includes `scripts/run-docker-runc-gpu.sh` for a Docker `runc` GPU-device bind-mount fallback and `scripts/run-native-alpha-miner.sh` for a native host fallback.
- Vast template docs should point to `vast/on-start.sh` for idle-host startup and `vast/native-fallback.md` when Docker GPU runtime creation fails.

## Validation Evidence

- Shell syntax passed for `entrypoint.sh`, GPU preset script, native fallback script, Docker fallback script, and Vast startup script.
- Mock entrypoint generated the expected merged address command: `--address prl1...+mdl1...`.
- Mock conflict test rejects duplicated MDL configuration.
- GPU preset dry-run matched `NVIDIA GeForce RTX 5090`, planned the expected 400 W power limit, 2490 MHz locked core, 7000 MHz locked memory, and exported `PEARL_PRESET_DIFFICULTY=1048576`.
- Docker build for `pearl-miner:1.8.6-test` completed and verified upstream `alpha-miner` checksum.

## Related Docs

- [[pearl-miner-runtime-2026-07-06]] is reflected in `README.md`, `env.example`, `docker-compose.yml`, `vast/README.md`, `vast/template.env.example`, `vast/idle-host-runbook.md`, and `vast/native-fallback.md`.
