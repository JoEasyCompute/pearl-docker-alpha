# Vast.ai Provider Default Job

Use this for the provider default job that runs while your own Vast-listed machine is idle and unrented.

This is different from the customer/renter template. The default job should be preempted or stopped by Vast before a renter gets the machine.

## Recommended Default Job Fields

| Field | Value |
| --- | --- |
| Docker image | `YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.7.9` |
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

Recommended for high-end cloud GPUs:

```text
PEARL_POOL_HOST=us2.alphapool.tech
PEARL_POOL_PORT=5566
PEARL_DIFFICULTY=1048576
PEARL_STATUS_INTERVAL=60
```

Pick the pool region closest to the provider host:

| Region | Host |
| --- | --- |
| US East | `us1.alphapool.tech` |
| US West | `us2.alphapool.tech` |
| Europe | `eu1.alphapool.tech` |
| Europe 2 | `eu2.alphapool.tech` |
| Russia / Eurasia | `ru1.alphapool.tech` |
| India | `in1.alphapool.tech` |
| Asia / Singapore | `sg1.alphapool.tech` |

## Normal Template Note

You can also create a normal Vast template with the same values for testing or manual launches. For mining on your own idle listed hosts, prefer the provider default job.

## Vast CLI Pattern

```bash
vastai create template \
  --image YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.7.9 \
  --env '-e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS -e PEARL_POOL_HOST=us2.alphapool.tech -e PEARL_DIFFICULTY=1048576'
```

Validate the exact CLI flags against your installed `vastai --help`; Vast has changed template flag names across CLI releases.
