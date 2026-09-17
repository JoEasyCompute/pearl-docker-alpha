# Pearl GPU Miner Docker Image

This repository builds a Docker image that mines Pearl (PRL) on NVIDIA GPUs using AlphaPool.

It is designed for two cases:

- Creating a Vast.ai provider default job that mines while your own listed machine is idle.
- Creating a normal Vast.ai template for testing or manual launches.

The image downloads AlphaPool's current `alpha-miner` Linux package, verifies both the pinned archive and its embedded files, and starts the upstream fleet launcher across all visible CUDA GPUs. The default build targets `alpha-miner v1.9.6 unified`, which provides certificate V3 proofs required by the current pool.

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
docker build --platform linux/amd64 -t pearl-miner:1.9.6 --build-arg ALPHA_MINER_VERSION=1.9.6 .
```

Why `linux/amd64` matters:

- Vast GPU hosts are normally AMD64/x86_64 Linux machines.
- The official Linux `alpha-miner` package is published for AMD64.
- If you build on Apple Silicon, this flag prevents Docker from accidentally building an ARM64 image that cannot run the miner.

The build should show this checksum line followed by checks for the embedded miner files:

```text
AlphaMiner-Linux-1.9.6-unified.tar.gz: OK
```

That means the downloaded package matched the repository's pinned SHA-256. The build then verifies all packaged binaries against the archive's internal `SHA256SUMS`.

## Step 4: Test the Image Locally

If your local machine has NVIDIA GPUs:

```bash
docker run --rm --gpus all \
  -e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  -e PEARL_WORKER=local-rig \
  -e PEARL_POOL_HOST=us2.alphapool.tech \
  -e PEARL_POOL_PORT=5566 \
  -e PEARL_DIFFICULTY=1048576 \
  pearl-miner:1.9.6
```

If your local machine does not have NVIDIA GPUs, you can still verify the image exists:

```bash
docker image ls pearl-miner
```

You can also verify the startup script rejects missing configuration:

```bash
docker run --rm pearl-miner:1.9.6
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
docker tag pearl-miner:1.9.6 YOUR_DOCKERHUB_USERNAME/pearl-miner:1.9.6
```

Push it:

```bash
docker push YOUR_DOCKERHUB_USERNAME/pearl-miner:1.9.6
```

Your Vast image name will be:

```text
YOUR_DOCKERHUB_USERNAME/pearl-miner:1.9.6
```

### Option B: GitHub Container Registry

Log in to GHCR:

```bash
docker login ghcr.io
```

Tag the image. Replace `YOUR_GITHUB_USERNAME`:

```bash
docker tag pearl-miner:1.9.6 ghcr.io/YOUR_GITHUB_USERNAME/pearl-miner:1.9.6
```

Push it:

```bash
docker push ghcr.io/YOUR_GITHUB_USERNAME/pearl-miner:1.9.6
```

Your Vast image name will be:

```text
ghcr.io/YOUR_GITHUB_USERNAME/pearl-miner:1.9.6
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
| Docker image | `YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.6` |
| Launch mode | `Docker ENTRYPOINT` |
| Disk | `8 GB` minimum |
| On-start script | Leave empty |

Environment variables:

```text
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS
PEARL_MDL_ADDRESS=
PEARL_WORKER=vast-rig
PEARL_POOL_HOST=us2.alphapool.tech
PEARL_POOL_PORT=5566
PEARL_DIFFICULTY=1048576
```

For MDL merge-mining with `alpha-miner v1.8.6+`, set:

```text
PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS
```

or put both chains directly in `PEARL_ADDRESS`:

```text
PEARL_ADDRESS=prl1YOUR_PRL+mdl1YOUR_MDL
```

Do not use both forms at the same time.

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
| Russia / Eurasia | `ru1.alphapool.tech` |
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
docker pull YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.6
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
  YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.6
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

## Step 10: Stop Or Restart

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

## Step 11: Update Alpha Miner

AlphaPool currently publishes its Linux setup and package at:

```text
https://pearl.alphapool.tech/#setup
```

Use pinned versions for normal operation. Avoid relying on `latest` for production because cloud hosts and Vast templates can cache images, and you want to know exactly which miner package is running.

Current upstream status checked on 2026-09-17:

- AlphaPool's live setup page requires certificate V3 and instructs Linux users to run `v1.9.6 unified`; the GitHub releases page still marks `v1.9.5.2` as latest and is stale relative to the pool.
- The Linux asset is `AlphaMiner-Linux-1.9.6-unified.tar.gz`. This repo pins the observed SHA-256 `cf231c87e405b2d8ccada41974633531874138662bf7219e8236c261261e46eb` because AlphaPool does not publish a separate checksum file beside the download.
- The fleet launcher automatically appends `.gN` to each GPU worker, preventing multi-GPU sessions from reusing one worker identity.
- The launcher supports compute capabilities 8.0 (CMP 170HX path), 8.6, 8.9, 9.0 beta, and 12.0; the RTX 5090 uses the 12.0 Blackwell core.
- The embedded package identifies itself as a public-test candidate and requests a qualification manifest that is not linked from the live setup page. Test one rig before fleet-wide rollout and retain the previous image tag for rollback.
- Rank, geometry, and backend overrides remain protected. Do not set `--gemm`, `--rank`, `--legacy-gemm`, `--force-backend`, `PEARL_XP*`, or `PEARL_XK_*`.
- `v1.8.6` introduced native MDL merge-mining with `prl1...+mdl1...`.

### Docker Image Update

Use `1.9.6` for the current certificate-V3 pool protocol.

Build the new image:

```bash
ALPHA_MINER_VERSION=1.9.6

docker build --platform linux/amd64 \
  -t pearl-miner:${ALPHA_MINER_VERSION} \
  --build-arg ALPHA_MINER_VERSION=${ALPHA_MINER_VERSION} \
  .
```

For future releases with a different source, asset filename, or published checksum, add the matching overrides:

```bash
--build-arg ALPHA_MINER_BASE_URL=https://example.com/releases \
--build-arg ALPHA_MINER_LINUX_ASSET=AlphaMiner-Linux-VERSION.tar.gz \
--build-arg ALPHA_MINER_SHA256=EXPECTED_ARCHIVE_SHA256
```

The default `auto` values know the AlphaPool-hosted `v1.9.6` package and the historical GitHub-hosted `v1.9.5.2` and `v1.9.1.02` package layouts.

The entrypoint also selects the matching CLI automatically: `v1.9.3+` uses the current `--host/--port/--worker` interface, while older rollback builds keep the legacy `--pool/--address` interface.

The build must show:

```text
AlphaMiner-Linux-1.9.6-unified.tar.gz: OK
```

That means the downloaded archive matched the pinned SHA-256; subsequent `OK` lines verify the internal manifest.

Tag and push the new image:

```bash
docker tag pearl-miner:${ALPHA_MINER_VERSION} YOUR_DOCKERHUB_OR_GHCR_IMAGE:${ALPHA_MINER_VERSION}
docker push YOUR_DOCKERHUB_OR_GHCR_IMAGE:${ALPHA_MINER_VERSION}
```

Update your Vast provider default job or template image from:

```text
YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.8.3
```

to:

```text
YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.6
```

Then redeploy/restart the default job or container. Vast may not pull the new image until the job is recreated or restarted.

### Manual Host Docker Update

On an idle host:

```bash
docker pull YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.6
docker rm -f pearl-miner
```

Then run the `docker run` command again with the new image tag:

```bash
YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.9.6
```

### Docker Compose Update

Edit [docker-compose.yml](docker-compose.yml) and change:

```yaml
ALPHA_MINER_VERSION: "1.9.7"
image: pearl-miner:1.9.7
```

to your chosen future version and matching image tag, for example:

```yaml
ALPHA_MINER_VERSION: "1.9.6"
image: pearl-miner:1.9.6
```

Then rebuild:

```bash
docker compose build --no-cache pearl-miner
docker compose up -d
docker compose logs -f pearl-miner
```

### Native Fallback Update

The native runner supports the same version variable:

```bash
ALPHA_MINER_VERSION=1.9.6 \
ALPHA_MINER_FORCE_DOWNLOAD=true \
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS \
PEARL_WORKER="$(hostname)-pearl" \
PEARL_POOL_HOST=us2.alphapool.tech \
PEARL_POOL_PORT=5566 \
PEARL_DIFFICULTY=1048576 \
./scripts/run-native-alpha-miner.sh
```

`ALPHA_MINER_FORCE_DOWNLOAD=true` forces the script to replace the existing wrapper under `$HOME/.local/bin/alpha-miner` and packaged runtime under `$HOME/.local/bin/alpha-miner-runtime`.

`ALPHA_MINER_VERSION=latest` also requires the exact current `ALPHA_MINER_LINUX_ASSET` because upstream asset names are versioned. Prefer a numbered version and image tag for reproducible builds and straightforward rollback.

### Roll Back

If v1.9.6 misbehaves or a host has package/runtime compatibility issues, return the template/default job/container to the previous stable image tag, for example:

```bash
docker pull YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.8.3
docker rm -f pearl-miner
```

Then run the `docker run` command again with `YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.8.3` and remove `PEARL_MDL_ADDRESS`.

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
| `PEARL_ADDRESS` | yes | none | Pearl payout address, must start with `prl1`; may also be `prl1...+mdl1...` for merge-mining |
| `PEARL_MDL_ADDRESS` | no | none | Optional MDL address starting with `mdl1`; appends to `PEARL_ADDRESS` for merge-mining on alpha-miner v1.8.6+ |
| `PEARL_WORKER` | no | container hostname | Worker label shown as `address.worker` |
| `PEARL_POOL_HOST` | no | `us2.alphapool.tech` | Use a stratum host, not `pearl.alphapool.tech` |
| `PEARL_POOL_PORT` | no | `5566` | `5566` is PPLNS; AlphaMine notes dedicated SOLO uses `5573`, not `5567` |
| `PEARL_POOL` / `PEARL_POOL_URL` | no | built from host/port | Full pool URL override |
| `PEARL_DIFFICULTY` | no | vardiff or matched preset | Sets password to `x;d=N`; overrides CSV preset difficulty when set |
| `PEARL_PASSWORD` | no | `x` | Ignored when `PEARL_DIFFICULTY` is set |
| `PEARL_DEVICES` | no | all visible GPUs | Comma-separated physical indexes; translated to `CUDA_VISIBLE_DEVICES` for the fleet launcher |
| `PEARL_FORCE_BACKEND` | no | rejected | The current launcher rejects user backend overrides |
| `PEARL_STATUS_INTERVAL` | no | `60` | Legacy miners before `v1.9.3` only; ignored by the current launcher |
| `PEARL_LIST_DEVICES` | no | false | Set `true` to print the `nvidia-smi` GPU index, name, and compute capability, then exit |
| `ALPHA_MINER_CLI_STYLE` | no | `auto` | Override only for an unusual package: `current` or `legacy` |

## Static Difficulty Guide

AlphaPool supports vardiff by default. Static difficulty can make cloud rigs start reporting stable shares faster.

Suggested values:

| GPU class | Suggested difficulty |
| --- | --- |
| RTX 3060 Ti / 3070 | `131072` |
| RTX 3080 / 3090 | `262144` |
| RTX 4070 / 4080 | `262144` |
| RTX 4090 / RTX 5080 / RTX 6000 Ada Generation | `524288` |
| RTX 5090 | `1048576` |

`v1.9.6` includes a compute-capability 9.0 beta path for H100-class GPUs. Its embedded README requires Ubuntu 24.04 / GLIBC 2.38 for the low-bandwidth H100 beta, while this Docker image remains Ubuntu 22.04 for RTX 30/40/50 compatibility. Validate non-RTX datacenter GPUs separately.

If you are unsure, start with:

```text
PEARL_DIFFICULTY=1048576
```

For smaller GPUs, lower it later if pool stats look unstable.

## Optional MDL Merge-Mining

`alpha-miner v1.8.6` added native MDL merge-mining. This image defaults to `v1.9.6` and constructs the current launcher's worker identity as `prl1...+mdl1....worker`.

### What Is MDL?

MDL is the ticker for modelOS. In the context of Pearl mining, MDL can be merge-mined with PRL: the same GPU shares submitted by `alpha-miner` can earn PRL and ModelOS (MDL) when the miner address includes both payout addresses.

Confirmed behavior from AlphaMine v1.8.6 release notes:

```text
prl1YOUR_PRL+mdl1YOUR_MDL
```

The HeroMiners ModelOS page describes modelOS/MDL as a Layer-1 Proof-of-Useful-Work project using GPU-heavy matrix multiplication related to AI workloads. Treat that as ecosystem context; AlphaMine's release notes are the source of truth for how `alpha-miner` accepts merge-mining addresses.

### Alpha Miner Protected Controls

The current launcher intentionally fails closed when manual rank, geometry, or backend controls are present. This preserves the safety policy introduced by the `v1.9.1.02` rank-128 hotfix.

Do not pass these controls:

```text
--gemm
--rank
--legacy-gemm
--force-backend
PEARL_XP
PEARL_XP_*
PEARL_XK_*
PEARL_FORCE_BACKEND
```

This repo rejects those env vars/arguments before launching the miner so misconfigured deployments fail clearly instead of mining with invalid work selection.

### Get an MDL Wallet Address

Use the ModelOS web wallet:

```text
https://compute.modeloslab.xyz/wallet
```

Steps:

1. Open the ModelOS wallet page.
2. Choose `Create new` or `Import existing`.
3. Set a strong password.
4. Create/open the wallet.
5. Copy your MDL receive address.
6. Confirm the address starts with `mdl1`.
7. Back up the wallet/seed/private key before mining to it.

Security notes:

- The scraped wallet page says keys are generated locally in your browser.
- Still treat it like any crypto wallet: back it up before sending mining rewards there.
- Do not put a wallet seed/private key into Docker env vars, Vast templates, `.env`, or this repository.
- Only the public `mdl1...` address belongs in miner configuration.

Enable merge-mining by adding an MDL address:

```bash
docker run --rm --gpus all \
  -e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  -e PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS \
  -e PEARL_WORKER=local-rig \
  -e PEARL_POOL_HOST=us2.alphapool.tech \
  -e PEARL_POOL_PORT=5566 \
  -e PEARL_DIFFICULTY=1048576 \
  pearl-miner:1.9.6
```

Or use AlphaMine's direct combined address form:

```bash
-e PEARL_ADDRESS=prl1YOUR_PRL+mdl1YOUR_MDL
```

Do not set both `PEARL_MDL_ADDRESS` and a `+mdl1...` suffix in `PEARL_ADDRESS`. The wrapper rejects that to avoid malformed addresses.

References:

- AlphaMine v1.8.6 merge-mining release: `https://github.com/AlphaMine-Tech/alpha-miner/releases/tag/v1.8.6`
- AlphaPool v1.9.6 setup: `https://pearl.alphapool.tech/#setup`
- ModelOS wallet page: `https://compute.modeloslab.xyz/wallet`
- HeroMiners ModelOS overview: `https://modelos.herominers.com/`

## Optional GPU Presets

The container can apply GPU tuning presets before starting `alpha-miner`. This is disabled by default so existing deployments behave the same.

Enable it by passing either a live CSV URL or `PEARL_GPU_PRESETS_ENABLE=true` with a mounted local CSV:

```bash
docker run --rm --gpus all \
  -e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  -e PEARL_GPU_PRESETS_URL=https://example.com/pearl-gpu-presets.csv \
  -e PEARL_GPU_PRESETS_DRY_RUN=true \
  pearl-miner:1.9.6
```

Run once with `PEARL_GPU_PRESETS_DRY_RUN=true` before production. Dry-run prints the commands that would be applied without changing clocks or power limits.

CSV schema:

```csv
enabled,algorithm,gpu_name_contains,pearl_difficulty,power_limit_w,lock_core_clock_mhz,core_clock_offset_mhz,lock_memory_clock_mhz,memory_clock_offset_mhz,fan_speed_pct,delay_before_apply_s
true,pearlhash,RTX 5090,1048576,400,2490,200,7000,,,0
true,pearlhash,RTX 4090,524288,360,2400,,7000,,,0
```

Rules:

- First matching row wins.
- `gpu_name_contains` is a case-insensitive substring matched against `nvidia-smi --query-gpu=name`.
- Empty fields are skipped.
- CSV fields must not contain commas.
- Missing preset files, missing GPU matches, and failed setting commands log warnings but do not block mining.
- `PEARL_DIFFICULTY` passed as an environment variable takes precedence over `pearl_difficulty` in the CSV.
- If `PEARL_DIFFICULTY` is unset, the first matched GPU preset with a valid `pearl_difficulty` sets the miner password to `x;d=<value>`.

Reliable best-effort Docker settings:

```bash
nvidia-smi -i GPU_INDEX -pm 1
nvidia-smi -i GPU_INDEX -pl POWER_LIMIT_W
nvidia-smi -i GPU_INDEX -lgc LOCK_CORE,LOCK_CORE
nvidia-smi -i GPU_INDEX -lmc LOCK_MEMORY,LOCK_MEMORY
```

HiveOS-style fields such as core offset, memory offset, fan speed, LEDs, pill settings, and reduced idle power may require host-level `nvidia-settings`, Xorg, or vendor-specific tooling. The container parses offset/fan fields, but it only attempts them if `nvidia-settings` and `DISPLAY` are available; otherwise it logs a warning and continues.

Preset environment variables:

| Variable | Default | Notes |
| --- | --- | --- |
| `PEARL_GPU_PRESETS_URL` | empty | Live CSV URL to fetch before mining |
| `PEARL_GPU_PRESETS_ENABLE` | `false` | Set `true` to use `PEARL_GPU_PRESETS_FILE` without a URL |
| `PEARL_GPU_PRESETS_FILE` | `/etc/pearl/gpu-presets.csv` | Local CSV path inside the container |
| `PEARL_GPU_PRESETS_ENV_FILE` | `/tmp/pearl-gpu-preset.env` | Internal env file used to pass matched preset difficulty to the entrypoint |
| `PEARL_GPU_PRESETS_DRY_RUN` | `false` | Print intended commands without applying settings |
| `PEARL_GPU_PRESETS_TIMEOUT` | `10` | Curl timeout in seconds |
| `PEARL_GPU_PRESETS_ALGORITHM` | `pearlhash` | CSV algorithm filter |

The repo includes editable examples:

- [examples/gpu-presets.csv](examples/gpu-presets.csv) for multiple GPU models.
- [examples/gpu-presets-5090-screenshot.csv](examples/gpu-presets-5090-screenshot.csv) with the RTX 5090 values from the screenshot.

To use a local file:

```bash
docker run --rm --gpus all \
  -v "$PWD/examples/gpu-presets.csv:/etc/pearl/gpu-presets.csv:ro" \
  -e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  -e PEARL_GPU_PRESETS_ENABLE=true \
  -e PEARL_GPU_PRESETS_DRY_RUN=true \
  pearl-miner:1.9.6
```

## Troubleshooting

### `PEARL_ADDRESS is required`

You did not set your wallet address.

Fix:

```bash
-e PEARL_ADDRESS=prl1pYOUR_REAL_ADDRESS
```

### `PEARL_ADDRESS must look like a Pearl mainnet address`

Your address does not start with `prl1`.

Use a Pearl mainnet receiving address from the Pearl wallet.

### `libcuda.so.1: cannot open shared object file`

The container cannot see the NVIDIA driver.

Check:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.3.2-runtime-ubuntu22.04 nvidia-smi
```

If the second command fails, install or fix NVIDIA Container Toolkit.

### Vast `kaalia_docker_shim` exits with status 101

Example:

```text
/var/lib/vastai_kaalia/latest/kaalia_docker_shim did not terminate successfully: exit status 101
```

This happens before the Pearl image starts. It is Vast's provider-side Docker shim failing during container creation.

First check whether normal Docker GPU containers work:

```bash
nvidia-smi
docker info | sed -n '/Runtimes:/,/Default Runtime:/p'
docker run --rm --gpus all nvidia/cuda:12.3.2-runtime-ubuntu22.04 nvidia-smi
```

If `--gpus all` triggers the Vast shim failure on a provider host, try Docker's NVIDIA runtime explicitly:

```bash
docker run --rm --runtime=nvidia \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  pearl-miner:1.9.6 \
  /bin/sh -lc 'nvidia-smi && test -x /usr/local/bin/alpha-miner && echo image-ok'
```

If that works, start the miner with the same runtime style:

```bash
docker rm -f pearl-miner 2>/dev/null || true

docker run -d --restart unless-stopped --runtime=nvidia \
  --name pearl-miner \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  -e PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  -e PEARL_WORKER="$(hostname)-pearl" \
  -e PEARL_POOL_HOST=us2.alphapool.tech \
  -e PEARL_POOL_PORT=5566 \
  -e PEARL_DIFFICULTY=1048576 \
  pearl-miner:1.9.6
```

If both `--gpus all` and `--runtime=nvidia` fail with `kaalia_docker_shim`, restart the Vast provider services or the host before trying again. The failure is below the container image layer.

If you need to mine immediately while Docker GPU runtime is broken, use the native fallback runner in [vast/native-fallback.md](vast/native-fallback.md). It downloads the same `alpha-miner` package, verifies the pinned archive plus its internal `SHA256SUMS`, and runs directly against the host NVIDIA driver.

If Docker works with `--runtime=runc`, you can also try the experimental manual GPU injection wrapper:

```bash
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS ./scripts/run-docker-runc-gpu.sh
```

This bypasses Vast's NVIDIA runtime by passing `/dev/nvidia*` and host driver libraries into the container manually. Prefer fixing the Vast/NVIDIA runtime for production use.

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
| `examples/gpu-presets.csv` | Editable GPU tuning preset CSV |
| `vast/README.md` | Short Vast provider default job and template notes |
| `vast/template.env.example` | Environment values for Vast default jobs or templates |
| `vast/on-start.sh` | Optional on-start script for non-entrypoint Vast modes |
| `vast/idle-host-runbook.md` | Manual fallback runbook for direct-host mining |
| `vast/native-fallback.md` | Native host fallback when Vast Docker GPU runtime fails |
| `scripts/run-native-alpha-miner.sh` | Native host runner that mirrors the Docker entrypoint |
| `scripts/run-docker-runc-gpu.sh` | Experimental Docker workaround that bypasses the NVIDIA runtime |
| `scripts/apply-gpu-presets.sh` | Best-effort GPU preset preflight for Docker |
| `scripts/alpha-miner-package.sh` | Shared package source, checksum, and layout resolver |
| `tests/entrypoint-test.sh` | Current and rollback CLI regression tests |
| `tests/package-config-test.sh` | Package source and checksum resolution tests |

## Sources Verified

- AlphaPool Pearl pool page: `https://pearl.alphapool.tech/`
- AlphaPool v1.9.6 unified Linux package: `https://pearl.alphapool.tech/releases/AlphaMiner-Linux-1.9.6-unified.tar.gz`
- AlphaMine official miner repository: `https://github.com/AlphaMine-Tech/alpha-miner`
- AlphaMine qualification manifest: `https://github.com/AlphaMine-Tech/alpha-miner/blob/main/QUALIFICATION-MANIFEST.txt`
- Pearl wallet releases: `https://github.com/pearl-research-labs/pearl/releases`
- AlphaMine v1.8.6 merge-mining release notes: `https://github.com/AlphaMine-Tech/alpha-miner/releases/tag/v1.8.6`
- AlphaMine v1.9.5.2 GitHub release (superseded for current pool connectivity): `https://github.com/AlphaMine-Tech/alpha-miner/releases/tag/v1.9.5.2`
- ModelOS wallet page: `https://compute.modeloslab.xyz/wallet`
