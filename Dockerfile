ARG IMAGE_PLATFORM=linux/amd64
FROM --platform=${IMAGE_PLATFORM} nvidia/cuda:12.3.2-runtime-ubuntu22.04

ARG ALPHA_MINER_VERSION=1.8.6

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then \
    echo "alpha-miner Linux binary is only published for linux/amd64" >&2; \
    exit 1; \
  fi; \
  if [ "${ALPHA_MINER_VERSION}" = "latest" ]; then \
    release_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/latest/download"; \
  else \
    release_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/download/v${ALPHA_MINER_VERSION}"; \
  fi; \
  curl -fsSL "${release_url}/alpha-miner" -o /usr/local/bin/alpha-miner; \
  curl -fsSL "${release_url}/SHA256SUMS" -o /tmp/SHA256SUMS; \
  cd /usr/local/bin; \
  grep -E '[[:space:]]+alpha-miner$' /tmp/SHA256SUMS | sha256sum -c -; \
  chmod 0755 /usr/local/bin/alpha-miner; \
  rm -f /tmp/SHA256SUMS

COPY entrypoint.sh /usr/local/bin/pearl-entrypoint
COPY scripts/apply-gpu-presets.sh /usr/local/bin/apply-gpu-presets
COPY examples/gpu-presets.csv /etc/pearl/gpu-presets.example.csv
RUN chmod 0755 /usr/local/bin/pearl-entrypoint /usr/local/bin/apply-gpu-presets

ENV NVIDIA_VISIBLE_DEVICES=all \
  NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  PEARL_POOL_HOST=us2.alphapool.tech \
  PEARL_POOL_PORT=5566 \
  PEARL_STATUS_INTERVAL=60 \
  PEARL_GPU_PRESETS_FILE=/etc/pearl/gpu-presets.csv \
  PEARL_GPU_PRESETS_ENV_FILE=/tmp/pearl-gpu-preset.env \
  PEARL_GPU_PRESETS_TIMEOUT=10 \
  PEARL_GPU_PRESETS_ALGORITHM=pearlhash

ENTRYPOINT ["/usr/local/bin/pearl-entrypoint"]
