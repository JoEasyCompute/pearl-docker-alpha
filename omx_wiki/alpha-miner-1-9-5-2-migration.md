---
title: "Alpha Miner 1.9.5.2 Migration"
tags: ["alpha-miner", "pearl", "docker", "release", "gpu"]
created: 2026-09-16T20:29:30.553Z
updated: 2026-09-16T20:29:30.553Z
sources: []
links: ["alpha-miner-hotfix-2026-08-07.md", "pearl-miner-runtime-2026-07-06.md"]
category: reference
confidence: medium
schemaVersion: 1
---

# Alpha Miner 1.9.5.2 Migration

## Upstream release

- Release: https://github.com/AlphaMine-Tech/alpha-miner/releases/tag/v1.9.5.2
- Published: 2026-08-23.
- Linux asset: `AlphaMiner-Linux-1.9.5.2.run`.
- Release SHA-256: `9eb23065e456bb5b35cca83b6d80c5adfca4dc4d068d102875b32eb489115361`.
- Main fix: correct pool hashrate credit for RTX 40- and 50-series GPUs.
- Qualification caveat: the embedded package labels itself a public-test candidate, and upstream's main-branch `QUALIFICATION-MANIFEST.txt` still lists only `v1.9.3`. Roll out to one rig first and retain the previous image tag.

## Package migration

The `.run` file is a Bash self-extracting archive. The Docker build verifies the outer asset against release `SHA256SUMS`, extracts the embedded tar payload, verifies the payload files against their internal `SHA256SUMS`, and installs the unified launcher under `/opt/alpha-miner`.

## CLI migration

The current launcher accepts `--host`, `--port`, `--worker`, `--password`, and optional split-form `--gpu N`. It no longer accepts the old `--pool`, `--address`, `--devices`, or `--status-interval` interface. The repo preserves its `PEARL_*` environment contract by composing `--worker` as `address.worker` and mapping `PEARL_DEVICES` to `CUDA_VISIBLE_DEVICES`. Omitting device selection activates upstream fleet mode across every supported visible GPU.

For rollback builds, the entrypoint and native runner automatically retain the legacy CLI for versions before `v1.9.3`. `ALPHA_MINER_CLI_STYLE=current|legacy` is available only as an escape hatch for unusually named packages.

## Supported GPUs

The package supports compute capabilities 8.6, 8.9, and 12.0. It does not ship cores for 8.0, 9.0, or 10.0, so A100, H100/H200, and B100/B200 hosts are unsupported by this release. Its fleet launcher starts one core per supported GPU and stops the fleet if a core exits. Rank, geometry, and backend overrides remain protected.

## Related history

See [[alpha-miner-hotfix-2026-08-07]] for the prior `v1.9.1.02` migration and [[pearl-miner-runtime-2026-07-06]] for the original GPU preset and merge-mining integration.
