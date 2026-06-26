# Pearl GPU Miner Docker Image

This repository builds a Docker image that mines Pearl (PRL) on NVIDIA GPUs using AlphaPool.

It is designed for two cases:

- Creating a Vast.ai provider default job that mines while your own listed machine is idle.
- Creating a normal Vast.ai template for testing or manual launches.

The image downloads the official `alpha-miner` Linux binary from `AlphaMine-Tech/alpha-miner`, verifies the release `SHA256SUMS`, and starts one miner process across all visible CUDA GPUs.

## Plain-English Overview

Mining needs four things:

1. A Pearl wallet address where payouts go.
2. A mining pool endpoint. This repo defaults to AlphaPool US West: `us2.alphapool.tech:5566`.
3. A Docker image that contains the miner.
4. A GPU machine that runs the Docker image.

The most important value is your wallet address:

```text
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS
```

Replace `prl1pYOUR_PRL_ADDRESS` everywhere with your real Pearl address.

Do not mine on a machine that is rented by someone else. For your own Vast.ai provider machines, the recommended setup is a Vast provider default job. Vast should run that job only while the machine is idle and stop it before a renter gets the GPUs.

## Step 1: Get a Pearl Wallet Address

1. Open the Pearl wallet releases page:
   `https://github.com/pearl-research-labs/pearl/releases`
2. Download the wallet for your operating system.
3. Install/open the wallet.
4. Create or open a wallet.
5. Copy your receive address.
6. Confirm it starts with `prl1p`.

Example placeholder:

```text
prl1pYOUR_PRL_ADDRESS
```

Use your real address, not the placeholder above.

## Step 2: Install Docker

On your local computer, install Docker Desktop or another Docker runtime.

Check Docker works:

```bash
docker --version
docker ps
```

On a GPU mining host, Docker also needs NVIDIA GPU support. Check the host can see GPUs:

```bash
nvidia-smi
```

Check Docker can use GPUs:

```bash
docker run --rm --gpus all nvidia/cuda:12.3.2-runtime-ubuntu22.04 nvidia-smi
```

If that command fails on a Linux GPU server, install or fix NVIDIA Container Toolkit before mining.

## Step 3: Build the Docker Image

Run this command from this repository directory:

```bash
docker build --platform linux/amd64 -t pearl-miner:1.7.9 --build-arg ALPHA_MINER_VERSION=1.7.9 .
```

Why `linux/amd64` matters:

- Vast GPU hosts are normally AMD64/x86_64 Linux machines.
- The official Linux `alpha-miner` binary is published for AMD64.
- If you build on Apple Silicon, this flag prevents Docker from accidentally building an ARM64 image that cannot run the miner.

The build should show this checksum line:

```text
alpha-miner: OK
```

That means the miner binary matched the official upstream checksum.

## Step 4: Test the Image Locally

If your local machine has NVIDIA GPUs:

```bash
docker run --rm --gpus all \
  -e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  -e PEARL_WORKER=local-rig \
  -e PEARL_POOL_HOST=us2.alphapool.tech \
  -e PEARL_POOL_PORT=5566 \
  -e PEARL_DIFFICULTY=1048576 \
  pearl-miner:1.7.9
```

If your local machine does not have NVIDIA GPUs, you can still verify the image exists:

```bash
docker image ls pearl-miner
```

You can also verify the startup script rejects missing configuration:

```bash
docker run --rm pearl-miner:1.7.9
```

Expected result:

```text
ERROR: PEARL_ADDRESS is required
```

## Step 5: Push the Image to a Registry

Vast.ai needs to pull the image from a public or authenticated container registry.

Common choices:

- Docker Hub
- GitHub Container Registry

### Option A: Docker Hub

Log in:

```bash
docker login
```

Tag the image. Replace `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username:

```bash
docker tag pearl-miner:1.7.9 YOUR_DOCKERHUB_USERNAME/pearl-miner:1.7.9
```

Push it:

```bash
docker push YOUR_DOCKERHUB_USERNAME/pearl-miner:1.7.9
```

Your Vast image name will be:

```text
YOUR_DOCKERHUB_USERNAME/pearl-miner:1.7.9
```

### Option B: GitHub Container Registry

Log in to GHCR:

```bash
docker login ghcr.io
```

Tag the image. Replace `YOUR_GITHUB_USERNAME`:

```bash
docker tag pearl-miner:1.7.9 ghcr.io/YOUR_GITHUB_USERNAME/pearl-miner:1.7.9
```

Push it:

```bash
docker push ghcr.io/YOUR_GITHUB_USERNAME/pearl-miner:1.7.9
```

Your Vast image name will be:

```text
ghcr.io/YOUR_GITHUB_USERNAME/pearl-miner:1.7.9
```

## Step 6: Create the Vast.ai Provider Default Job

Use this section for the main goal: mining on your own listed machines while they are idle.

In Vast provider terms, this is the default job or idle job. It is different from the template renters use. The default job is your own workload that runs when nobody has rented the machine.

Expected behavior:

1. Your machine is listed on Vast.
2. Nobody is renting it.
3. Vast starts the default job.
4. The default job runs this Pearl miner image.
5. A customer rents the machine.
6. Vast stops or preempts the default job.
7. The customer gets the GPUs without your miner running.

Create or edit the provider default job for the host and use these values:

| Field | Value |
| --- | --- |
| Docker image | `YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.7.9` |
| Launch mode | `Docker ENTRYPOINT` |
| Disk | `8 GB` minimum |
| On-start script | Leave empty |

Environment variables:

```text
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS
PEARL_WORKER=vast-rig
PEARL_POOL_HOST=us2.alphapool.tech
PEARL_POOL_PORT=5566
PEARL_DIFFICULTY=1048576
PEARL_STATUS_INTERVAL=60
```

Recommended `PEARL_DIFFICULTY` values for your listed GPU types:

| GPU | Recommended setting |
| --- | --- |
| RTX 4090 | `PEARL_DIFFICULTY=524288` |
| RTX 5090 | `PEARL_DIFFICULTY=1048576` |
| RTX 6000 Ada Generation | `PEARL_DIFFICULTY=524288` |

Important: do not use `pearl.alphapool.tech` as the mining host. That is the website. Use a stratum host such as `us2.alphapool.tech`.

If your Vast UI calls this feature something slightly different, look for provider settings related to default jobs, idle jobs, or the workload that runs when the machine is unrented.

## Optional: Create a Normal Vast.ai Template

Use this only for testing, manual launches, or if you want to rent an instance yourself. This is not the preferred way to mine on your own idle provider hosts.

1. Log in to Vast.ai.
2. Go to the template creation page.
3. Create a new Docker template.
4. Set the Docker image to the image you pushed.
5. Set launch mode to `Docker ENTRYPOINT`.
6. Set disk size to at least `8 GB`.
7. Add the same environment variables from Step 6.
8. Save the template.

## Step 7: Pick the Right Pool Region

Use the pool host closest to the GPU machine.

| Region | Host |
| --- | --- |
| US East | `us1.alphapool.tech` |
| US West | `us2.alphapool.tech` |
| Europe | `eu1.alphapool.tech` |
| Europe 2 | `eu2.alphapool.tech` |
| Russia / Eurasia | `ru1.alphapool.tech` |
| India | `in1.alphapool.tech` |
| Asia / Singapore | `sg1.alphapool.tech` |

Only change `PEARL_POOL_HOST`. Keep `PEARL_POOL_PORT=5566` for normal PPLNS pool mining.

## Step 8: Manual Fallback For Your Own Idle Vast-Listed Hosts

Use this only if you cannot configure a Vast provider default job.

This method is riskier than a default job because Vast will not necessarily manage the miner lifecycle for you. You must stop the miner before the machine is made available to renters.

SSH into the host:

```bash
ssh YOUR_USER@YOUR_HOST
```

Check the GPUs:

```bash
nvidia-smi
```

Pull your published image:

```bash
docker pull YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.7.9
```

Stop any existing Pearl miner container:

```bash
docker rm -f pearl-miner 2>/dev/null || true
```

Start mining:

```bash
docker run -d --restart unless-stopped --gpus all \
  --name pearl-miner \
  -e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  -e PEARL_WORKER="$(hostname)-pearl" \
  -e PEARL_POOL_HOST=us2.alphapool.tech \
  -e PEARL_POOL_PORT=5566 \
  -e PEARL_DIFFICULTY=1048576 \
  YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.7.9
```

View logs:

```bash
docker logs -f pearl-miner
```

Stop mining before renting the machine to customers:

```bash
docker rm -f pearl-miner
```

## Step 9: Confirm Mining Is Working

On the host, check the container is running:

```bash
docker ps --filter name=pearl-miner
```

View recent logs:

```bash
docker logs --tail 100 pearl-miner
```

Watch live logs:

```bash
docker logs -f pearl-miner
```

You should see the miner connect to AlphaPool and start submitting shares.

Then open:

```text
https://pearl.alphapool.tech/
```

Use the dashboard lookup with your Pearl address.

Your worker name should appear as:

```text
prl1pYOUR_PRL_ADDRESS.worker-name
```

## Step 10: Stop, Restart, Or Update

Stop mining:

```bash
docker stop pearl-miner
```

Start it again:

```bash
docker start pearl-miner
```

Remove it completely:

```bash
docker rm -f pearl-miner
```

Update to a newer image after rebuilding and pushing:

```bash
docker pull YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.7.9
docker rm -f pearl-miner
```

Then run the `docker run` command again.

## Docker Compose Option

Use this if you prefer a `.env` file instead of typing environment variables into the command line.

Create `.env`:

```bash
cp env.example .env
```

Edit `.env` and set:

```text
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS
```

Start:

```bash
docker compose up --build -d
```

View logs:

```bash
docker compose logs -f pearl-miner
```

Stop:

```bash
docker compose down
```

## Environment Variable Reference

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `PEARL_ADDRESS` | yes | none | Pearl payout address, must start with `prl1p` |
| `PEARL_WORKER` | no | container hostname | Worker label shown as `address.worker` |
| `PEARL_POOL_HOST` | no | `us2.alphapool.tech` | Use a stratum host, not `pearl.alphapool.tech` |
| `PEARL_POOL_PORT` | no | `5566` | `5566` is PPLNS; `5567` is solo when available |
| `PEARL_POOL` / `PEARL_POOL_URL` | no | built from host/port | Full pool URL override |
| `PEARL_DIFFICULTY` | no | vardiff | Sets password to `x;d=N` |
| `PEARL_PASSWORD` | no | `x` | Ignored when `PEARL_DIFFICULTY` is set |
| `PEARL_DEVICES` | no | all visible GPUs | Example: `0,1,2` |
| `PEARL_FORCE_BACKEND` | no | auto | `volta`, `ampere`, `ada`, `hopper`, `blackwell`, or `blackwell-native` |
| `PEARL_STATUS_INTERVAL` | no | `60` | Miner status log interval in seconds |
| `PEARL_LIST_DEVICES` | no | false | Set `true` to run `alpha-miner --list-devices` and exit |

## Static Difficulty Guide

AlphaPool supports vardiff by default. Static difficulty can make cloud rigs start reporting stable shares faster.

Suggested values:

| GPU class | Suggested difficulty |
| --- | --- |
| RTX 3060 Ti / 3070 | `131072` |
| RTX 3080 / 3090 | `262144` |
| A100 | `131072` |
| RTX 4070 / 4080 | `262144` |
| RTX 4090 / RTX 5080 / RTX 6000 Ada Generation | `524288` |
| RTX 5090 / H100 / H200 / B100 | `1048576` |

If you are unsure, start with:

```text
PEARL_DIFFICULTY=1048576
```

For smaller GPUs, lower it later if pool stats look unstable.

## Troubleshooting

### `PEARL_ADDRESS is required`

You did not set your wallet address.

Fix:

```bash
-e PEARL_ADDRESS=prl1pYOUR_REAL_ADDRESS
```

### `PEARL_ADDRESS must look like a Pearl mainnet address`

Your address does not start with `prl1p`.

Use a Pearl mainnet receiving address from the Pearl wallet.

### `libcuda.so.1: cannot open shared object file`

The container cannot see the NVIDIA driver.

Check:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.3.2-runtime-ubuntu22.04 nvidia-smi
```

If the second command fails, install or fix NVIDIA Container Toolkit.

### Miner connects to the wrong host

Do not use:

```text
pearl.alphapool.tech
```

Use:

```text
us2.alphapool.tech
```

or another stratum region from the region table.

### Vast default job or template starts but miner does not run

Check the template launch mode.

Use:

```text
Docker ENTRYPOINT
```

Avoid SSH/Jupyter launch modes unless you explicitly configure an on-start script.

### Default job keeps running when a customer rents the machine

This is a provider orchestration problem, not a miner problem. Stop the miner immediately:

```bash
docker rm -f pearl-miner
```

Then fix the Vast provider default job/preemption settings before enabling the miner again.

### Machine is rented by a customer

Do not run the miner. Stop it:

```bash
docker rm -f pearl-miner
```

## Files In This Repository

| File | Purpose |
| --- | --- |
| `Dockerfile` | Builds the miner image |
| `entrypoint.sh` | Validates settings and starts `alpha-miner` |
| `docker-compose.yml` | Local compose setup |
| `env.example` | Example local environment file |
| `vast/README.md` | Short Vast provider default job and template notes |
| `vast/template.env.example` | Environment values for Vast default jobs or templates |
| `vast/on-start.sh` | Optional on-start script for non-entrypoint Vast modes |
| `vast/idle-host-runbook.md` | Manual fallback runbook for direct-host mining |

## Sources Verified

- AlphaPool Pearl pool page: `https://pearl.alphapool.tech/`
- AlphaMine official miner repository: `https://github.com/AlphaMine-Tech/alpha-miner`
- Pearl wallet releases: `https://github.com/pearl-research-labs/pearl/releases`
