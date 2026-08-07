# Alpha Miner Hotfix 2026-08-07

Category: session-log
Tags: pearl, alpha-miner, hotfix, docker, vast, deployment

## Upstream Release

- AlphaMine release: `https://github.com/AlphaMine-Tech/alpha-miner/releases/tag/v1.9.1.02`
- Release name: `Alpha Miner 1.9.1b Emergency Rank-128 Hotfix`.
- Published on 2026-08-07.
- Linux Ubuntu asset: `alpha-miner-1.9.1b-ubuntu-amd64.tar.gz`.
- SHA256 from upstream `SHA256SUMS`: `ea3ec59664a6db6c40acd2db35d1b1de05d04edeb53e1d0c2e56d4df051afb42`.

## Repo Decisions

- Default `ALPHA_MINER_VERSION` is now `1.9.1.02`.
- Docker build now supports the tarball package layout and installs the packaged wrapper plus hidden `.alpha-miner-core` under `/opt/alpha-miner`.
- Native fallback now installs a wrapper under `$HOME/.local/bin/alpha-miner` and runtime files under `$HOME/.local/bin/alpha-miner-runtime`.
- The native runner writes a version marker so changing `ALPHA_MINER_VERSION` triggers a re-download without requiring manual cleanup.
- Older standalone `alpha-miner` binary releases remain supported by setting `ALPHA_MINER_LINUX_ASSET=alpha-miner` or using an older version with `auto`.

## Safety Rules

- The hotfix rejects manual backend/rank/GEMM controls.
- Do not set `PEARL_FORCE_BACKEND`, `PEARL_XP`, `PEARL_XP_*`, `PEARL_XK_*`, `--gemm`, `--rank`, `--legacy-gemm`, or `--force-backend`.
- The repo entrypoint and native fallback reject those controls before launching the miner to fail clearly.
- AlphaMine notes PPLNS is port `5566`; dedicated SOLO is port `5573`, not `5567`.

## Deployment Note

- Operator provided build and redeploy SSH targets in the working session.
- Exact host/IP/port details are intentionally not committed to the public repo wiki; keep operational endpoints in private runbooks or deployment tooling.

## Related Docs

- `README.md`
- `env.example`
- `docker-compose.yml`
- `vast/README.md`
- `vast/template.env.example`
- `vast/idle-host-runbook.md`
- `vast/native-fallback.md`
