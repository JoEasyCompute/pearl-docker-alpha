# Native Fallback When Vast Docker GPU Runtime Fails

Use this only when Docker GPU containers fail before the image starts, for example:

```text
/var/lib/vastai_kaalia/latest/kaalia_docker_shim did not terminate successfully: exit status 101
```

That failure is below the Pearl image layer. The host NVIDIA driver may still work, so you can run the official `alpha-miner` directly while you repair the Vast Docker runtime.

## Foreground Test

From this repository on the host:

```bash
chmod +x scripts/run-native-alpha-miner.sh

PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS \
PEARL_WORKER="$(hostname)-pearl" \
PEARL_POOL_HOST=us2.alphapool.tech \
PEARL_POOL_PORT=5566 \
PEARL_DIFFICULTY=1048576 \
./scripts/run-native-alpha-miner.sh
```

Stop with `Ctrl+C`.

## Background Run

```bash
mkdir -p logs

nohup env \
  PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
  PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS \
  PEARL_WORKER="$(hostname)-pearl" \
  PEARL_POOL_HOST=us2.alphapool.tech \
  PEARL_POOL_PORT=5566 \
  PEARL_DIFFICULTY=1048576 \
  ./scripts/run-native-alpha-miner.sh > logs/pearl-native.log 2>&1 &

echo $! > logs/pearl-native.pid
```

View logs:

```bash
tail -f logs/pearl-native.log
```

Stop:

```bash
kill "$(cat logs/pearl-native.pid)"
```

## Update Native Alpha Miner

The native runner defaults to `ALPHA_MINER_VERSION=1.9.1.02`. To update or roll back, choose a release from:

```text
https://github.com/AlphaMine-Tech/alpha-miner/releases
```

Then force a re-download:

```bash
ALPHA_MINER_VERSION=1.9.1.02 \
ALPHA_MINER_FORCE_DOWNLOAD=true \
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS \
PEARL_WORKER="$(hostname)-pearl" \
PEARL_POOL_HOST=us2.alphapool.tech \
PEARL_POOL_PORT=5566 \
PEARL_DIFFICULTY=1048576 \
./scripts/run-native-alpha-miner.sh
```

The script downloads the matching Linux package, downloads `SHA256SUMS`, verifies the package, and installs a wrapper plus runtime files:

```text
$HOME/.local/bin/alpha-miner
$HOME/.local/bin/alpha-miner-runtime/
```

For `v1.9.1.02`, do not set `PEARL_FORCE_BACKEND`, `PEARL_XP*`, `PEARL_XK_*`, `--gemm`, `--rank`, `--legacy-gemm`, or `--force-backend`; the hotfix rejects those controls.

To roll back, run the same command with the previous version:

```bash
ALPHA_MINER_VERSION=1.8.3 \
ALPHA_MINER_FORCE_DOWNLOAD=true \
PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
./scripts/run-native-alpha-miner.sh
```

## Repair Docker Separately

These commands show whether Docker itself or only the NVIDIA/Vast shim is broken:

```bash
docker run --rm --runtime=runc hello-world
docker run --rm --runtime=runc nvidia/cuda:12.3.2-runtime-ubuntu22.04 /bin/true
docker run --rm --runtime=nvidia nvidia/cuda:12.3.2-runtime-ubuntu22.04 nvidia-smi
```

If `--runtime=runc` works but `--runtime=nvidia` fails, repair or restart the Vast/NVIDIA container runtime on the provider host. The native miner can keep running only while the host is idle and not rented.

## Experimental Docker Workaround With `runc`

If plain Docker works with `--runtime=runc`, you can try bypassing the broken Vast NVIDIA runtime and manually injecting GPU devices plus host driver libraries:

```bash
chmod +x scripts/run-docker-runc-gpu.sh

PEARL_ADDRESS=prl1pYOUR_PRL_ADDRESS \
PEARL_MDL_ADDRESS=mdl1YOUR_MDL_ADDRESS \
PEARL_WORKER="$(hostname)-pearl" \
PEARL_POOL_HOST=us2.alphapool.tech \
PEARL_POOL_PORT=5566 \
PEARL_DIFFICULTY=1048576 \
./scripts/run-docker-runc-gpu.sh
```

View logs:

```bash
docker logs -f pearl-miner
```

This is intentionally a workaround. It mounts host `/dev/nvidia*` devices and driver libraries into the container by hand. If it fails, use the native runner above or repair the Vast/NVIDIA runtime.
