ARG IMAGE_PLATFORM=linux/amd64
FROM --platform=${IMAGE_PLATFORM} nvidia/cuda:12.3.2-runtime-ubuntu22.04

ARG ALPHA_MINER_VERSION=1.9.6
ARG ALPHA_MINER_LINUX_ASSET=auto
ARG ALPHA_MINER_BASE_URL=auto
ARG ALPHA_MINER_SHA256=auto

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl tar util-linux \
  && rm -rf /var/lib/apt/lists/*

COPY scripts/alpha-miner-package.sh /usr/local/lib/alpha-miner-package.sh

RUN set -eux; \
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then \
    echo "alpha-miner Linux package is only published for linux/amd64" >&2; \
    exit 1; \
  fi; \
  . /usr/local/lib/alpha-miner-package.sh; \
  alpha_miner_resolve_package "${ALPHA_MINER_VERSION}" "${ALPHA_MINER_LINUX_ASSET}" "${ALPHA_MINER_BASE_URL}" "${ALPHA_MINER_SHA256}"; \
  linux_asset="${ALPHA_MINER_RESOLVED_ASSET}"; \
  curl -fsSL "${ALPHA_MINER_PACKAGE_URL}" -o "/tmp/${linux_asset}"; \
  cd /tmp; \
  if [ -n "${ALPHA_MINER_RESOLVED_SHA256}" ]; then \
    printf '%s  %s\n' "${ALPHA_MINER_RESOLVED_SHA256}" "${linux_asset}" | sha256sum -c -; \
  else \
    curl -fsSL "${ALPHA_MINER_CHECKSUM_URL}" -o /tmp/SHA256SUMS; \
    grep -E "[[:space:]]+${linux_asset}$" SHA256SUMS | sha256sum -c -; \
  fi; \
  if [ "${ALPHA_MINER_PACKAGE_LAYOUT}" = "standalone" ]; then \
    install -m 0755 "/tmp/${linux_asset}" /usr/local/bin/alpha-miner; \
  else \
    mkdir -p /tmp/alpha-miner-extract /opt/alpha-miner; \
    if [ "${ALPHA_MINER_PACKAGE_LAYOUT}" = "self-extracting" ]; then \
      payload_line="$(awk '/^__ALPHAMINER_PAYLOAD_BELOW__$/{print NR + 1; exit}' "/tmp/${linux_asset}")"; \
      test -n "${payload_line}"; \
      tail -n +"${payload_line}" "/tmp/${linux_asset}" > /tmp/alpha-miner-payload.tar.gz; \
      tar xzf /tmp/alpha-miner-payload.tar.gz -C /tmp/alpha-miner-extract; \
    else \
      tar xzf "/tmp/${linux_asset}" -C /tmp/alpha-miner-extract; \
    fi; \
    package_dir="$(find /tmp/alpha-miner-extract -mindepth 1 -maxdepth 1 -type d | head -n 1)"; \
    test -n "${package_dir}"; \
    if [ "${ALPHA_MINER_PACKAGE_LAYOUT}" = "legacy-tar" ]; then \
      test -x "${package_dir}/alpha-miner"; \
      test -f "${package_dir}/.alpha-miner-core"; \
    else \
      cd "${package_dir}"; \
      sha256sum -c SHA256SUMS; \
    fi; \
    cp -a "${package_dir}/." /opt/alpha-miner/; \
    test -x /opt/alpha-miner/alpha-miner; \
    printf '%s\n' '#!/usr/bin/env sh' 'exec /opt/alpha-miner/alpha-miner "$@"' > /usr/local/bin/alpha-miner; \
    chmod 0755 /usr/local/bin/alpha-miner /opt/alpha-miner/alpha-miner; \
    if [ "${ALPHA_MINER_PACKAGE_LAYOUT}" = "legacy-tar" ]; then chmod 0755 /opt/alpha-miner/.alpha-miner-core; fi; \
  fi; \
  rm -rf /tmp/SHA256SUMS "/tmp/${linux_asset}" /tmp/alpha-miner-payload.tar.gz /tmp/alpha-miner-extract

COPY entrypoint.sh /usr/local/bin/pearl-entrypoint
COPY scripts/apply-gpu-presets.sh /usr/local/bin/apply-gpu-presets
COPY examples/gpu-presets.csv /etc/pearl/gpu-presets.example.csv
RUN chmod 0755 /usr/local/bin/pearl-entrypoint /usr/local/bin/apply-gpu-presets

ENV ALPHA_MINER_VERSION=${ALPHA_MINER_VERSION} \
  NVIDIA_VISIBLE_DEVICES=all \
  NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  PEARL_POOL_HOST=us2.alphapool.tech \
  PEARL_POOL_PORT=5566 \
  PEARL_GPU_PRESETS_FILE=/etc/pearl/gpu-presets.csv \
  PEARL_GPU_PRESETS_ENV_FILE=/tmp/pearl-gpu-preset.env \
  PEARL_GPU_PRESETS_TIMEOUT=10 \
  PEARL_GPU_PRESETS_ALGORITHM=pearlhash

RUN mkdir -p /var/lib/alpha-miner
WORKDIR /var/lib/alpha-miner

ENTRYPOINT ["/usr/local/bin/pearl-entrypoint"]
