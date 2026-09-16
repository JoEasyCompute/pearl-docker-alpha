# Vast.ai Provider Default Job

Use this for the provider default job that runs while your own Vast-listed machine is idle and unrented.

This is different from the customer/renter template. The default job should be preempted or stopped by Vast before a renter gets the machine.

The default image examples use `alpha-miner v1.9.5.2`, released on 2026-08-23 with the RTX 40/50-series pool-hashrate credit fix.

## Recommended Default Job Fields

| Field | Value |
| --- | --- |
| Docker image | `YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.5.2` |
| Launch mode | `Docker ENTRYPOINT` |
| Disk | `8 GB` minimum |
| Environment | Paste values from `vast/template.env.example` |
| On-start script | Leave empty for `Docker ENTRYPOINT` mode |

Do not select an SSH or Jupyter launch mode if you expect mining to start from the image entrypoint. Those modes are useful for debugging, but they may bypass the mining entrypoint. If you must use SSH/Jupyter mode, paste `vast/on-start.sh` into Vast's on-start script field.

## Environment

Required:

```text
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS
```

Optional MDL merge-mining on `alpha-miner v1.8.6+`:

```text
PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS
```

Recommended for high-end cloud GPUs:

```text
PEARL_POOL_HOST=us2.alphapool.tech
PEARL_POOL_PORT=5566
PEARL_DIFFICULTY=1048576
```

Pick the pool region closest to the provider host:

| Region | Host |
| --- | --- |
| US East | `us1.alphapool.tech` |
| US West | `us2.alphapool.tech` |
| Europe | `eu1.alphapool.tech` |
| Russia / Eurasia | `ru1.alphapool.tech` |
| Asia / Singapore | `sg1.alphapool.tech` |

The `v1.9.5.2` package supports compute capabilities 8.6, 8.9, and 12.0. Test one RTX 40/50-series rig before a fleet rollout because the embedded package is labeled a public-test candidate and upstream's qualification manifest still covers `v1.9.3`.

## Normal Template Note

You can also create a normal Vast template with the same values for testing or manual launches. For mining on your own idle listed hosts, prefer the provider default job.

## Updating Alpha Miner

Build and push a new image tag with the upstream miner version:

```bash
ALPHA_MINER_VERSION=1.9.5.2

docker build --platform linux/amd64 \
  -t pearl-miner:${ALPHA_MINER_VERSION} \
  --build-arg ALPHA_MINER_VERSION=${ALPHA_MINER_VERSION} \
  .

docker tag pearl-miner:${ALPHA_MINER_VERSION} YOUR_DOCKERHUB_OR_GHCR_IMAGE:${ALPHA_MINER_VERSION}
docker push YOUR_DOCKERHUB_OR_GHCR_IMAGE:${ALPHA_MINER_VERSION}
```

Then update the Vast provider default job image field to the new tag and redeploy/restart it:

```text
YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.5.2
```

Do not rely on `latest` for default jobs. A numbered tag makes rollback straightforward.

## Rebuild And Redeploy Pattern

Use the build host to pull the repo, build the pinned image, tag it for your registry, and push it:

```bash
ALPHA_MINER_VERSION=1.9.5.2
IMAGE=YOUR_DOCKERHUB_OR_GHCR_IMAGE:${ALPHA_MINER_VERSION}

git pull
docker build --platform linux/amd64 \
  -t pearl-miner:${ALPHA_MINER_VERSION} \
  --build-arg ALPHA_MINER_VERSION=${ALPHA_MINER_VERSION} \
  .
docker tag pearl-miner:${ALPHA_MINER_VERSION} "$IMAGE"
docker push "$IMAGE"
```

On each idle redeploy host, pull the new image and recreate the miner container:

```bash
IMAGE=YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.5.2

docker pull "$IMAGE"
docker rm -f pearl-miner || true
docker run -d --restart unless-stopped --gpus all \
  --name pearl-miner \
  -e PEARL_ADDRESS="$PEARL_ADDRESS" \
  -e PEARL_MDL_ADDRESS="${PEARL_MDL_ADDRESS:-}" \
  -e PEARL_WORKER="$(hostname)-pearl" \
  -e PEARL_POOL_HOST="${PEARL_POOL_HOST:-us2.alphapool.tech}" \
  -e PEARL_POOL_PORT="${PEARL_POOL_PORT:-5566}" \
  -e PEARL_DIFFICULTY="${PEARL_DIFFICULTY:-1048576}" \
  "$IMAGE"
docker logs --tail 80 pearl-miner
```

## Alpha Miner 1.9.5.2 Safety Note

Do not set manual backend/rank/GEMM controls in Vast env vars or extra arguments. The current launcher intentionally rejects:

```text
PEARL_FORCE_BACKEND
PEARL_XP
PEARL_XP_*
PEARL_XK_*
--gemm
--rank
--legacy-gemm
--force-backend
```

## Vast CLI Pattern

```bash
vastai create template \
  --image YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.5.2 \
  --env '-e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS -e PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS -e PEARL_POOL_HOST=us2.alphapool.tech -e PEARL_DIFFICULTY=1048576'
```

Validate the exact CLI flags against your installed `vastai --help`; Vast has changed template flag names across CLI releases.
