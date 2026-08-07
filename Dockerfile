ARG IMAGE_PLATFORM=linux/amd64
FROM --platform=${IMAGE_PLATFORM} nvidia/cuda:12.3.2-runtime-ubuntu22.04

ARG ALPHA_MINER_VERSION=1.9.1.02
ARG ALPHA_MINER_LINUX_ASSET=auto

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl tar \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then \
    echo "alpha-miner Linux package is only published for linux/amd64" >&2; \
    exit 1; \
  fi; \
  if [ "${ALPHA_MINER_VERSION}" = "latest" ]; then \
    release_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/latest/download"; \
  else \
    release_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/download/v${ALPHA_MINER_VERSION}"; \
  fi; \
  linux_asset="${ALPHA_MINER_LINUX_ASSET}"; \
  if [ "${linux_asset}" = "auto" ]; then \
    if [ "${ALPHA_MINER_VERSION}" = "1.9.1.02" ]; then \
      linux_asset="alpha-miner-1.9.1b-ubuntu-amd64.tar.gz"; \
    else \
      linux_asset="alpha-miner"; \
    fi; \
  fi; \
  curl -fsSL "${release_url}/SHA256SUMS" -o /tmp/SHA256SUMS; \
  if [ "${linux_asset}" = "alpha-miner" ]; then \
    curl -fsSL "${release_url}/alpha-miner" -o /usr/local/bin/alpha-miner; \
    cd /usr/local/bin; \
    grep -E '[[:space:]]+alpha-miner$' /tmp/SHA256SUMS | sha256sum -c -; \
    chmod 0755 /usr/local/bin/alpha-miner; \
  else \
    curl -fsSL "${release_url}/${linux_asset}" -o "/tmp/${linux_asset}"; \
    cd /tmp; \
    grep -E "[[:space:]]+${linux_asset}$" SHA256SUMS | sha256sum -c -; \
    mkdir -p /tmp/alpha-miner-extract /opt/alpha-miner; \
    tar xzf "/tmp/${linux_asset}" -C /tmp/alpha-miner-extract; \
    package_dir="$(find /tmp/alpha-miner-extract -mindepth 1 -maxdepth 1 -type d | head -n 1)"; \
    test -n "${package_dir}"; \
    cp -a "${package_dir}/." /opt/alpha-miner/; \
    test -x /opt/alpha-miner/alpha-miner; \
    test -f /opt/alpha-miner/.alpha-miner-core; \
    printf '%s\n' '#!/usr/bin/env sh' 'exec /opt/alpha-miner/alpha-miner "$@"' > /usr/local/bin/alpha-miner; \
    chmod 0755 /usr/local/bin/alpha-miner /opt/alpha-miner/alpha-miner /opt/alpha-miner/.alpha-miner-core; \
  fi; \
  rm -rf /tmp/SHA256SUMS "/tmp/${linux_asset}" /tmp/alpha-miner-extract

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
