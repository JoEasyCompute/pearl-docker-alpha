#!/usr/bin/env sh

alpha_miner_resolve_package() {
  alpha_version="$1"
  alpha_asset="$2"
  alpha_base_url="$3"
  alpha_sha256="$4"

  if [ "$alpha_base_url" = "auto" ]; then
    if [ "$alpha_version" = "1.9.6" ]; then
      alpha_base_url="https://pearl.alphapool.tech/releases"
    elif [ "$alpha_version" = "latest" ]; then
      alpha_base_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/latest/download"
    else
      alpha_base_url="https://github.com/AlphaMine-Tech/alpha-miner/releases/download/v${alpha_version}"
    fi
  fi
  alpha_base_url="${alpha_base_url%/}"

  if [ "$alpha_asset" = "auto" ]; then
    case "$alpha_version" in
      1.9.6) alpha_asset="AlphaMiner-Linux-1.9.6-unified.tar.gz" ;;
      1.9.5.2) alpha_asset="AlphaMiner-Linux-1.9.5.2.run" ;;
      1.9.1.02) alpha_asset="alpha-miner-1.9.1b-ubuntu-amd64.tar.gz" ;;
      latest)
        printf '%s\n' "Set ALPHA_MINER_LINUX_ASSET when building an unpinned latest release" >&2
        return 1
        ;;
      *) alpha_asset="alpha-miner" ;;
    esac
  fi

  if [ "$alpha_sha256" = "auto" ]; then
    if [ "$alpha_version" = "1.9.6" ]; then
      alpha_sha256="cf231c87e405b2d8ccada41974633531874138662bf7219e8236c261261e46eb"
    else
      alpha_sha256=""
    fi
  fi

  case "$alpha_asset" in
    *.run) alpha_layout="self-extracting" ;;
    *.tar.gz)
      if [ "$alpha_version" = "1.9.1.02" ]; then
        alpha_layout="legacy-tar"
      else
        alpha_layout="unified-tar"
      fi
      ;;
    alpha-miner) alpha_layout="standalone" ;;
    *)
      printf '%s\n' "Cannot infer package layout from asset: ${alpha_asset}" >&2
      return 1
      ;;
  esac

  ALPHA_MINER_RESOLVED_ASSET="$alpha_asset"
  ALPHA_MINER_PACKAGE_URL="${alpha_base_url}/${alpha_asset}"
  ALPHA_MINER_RESOLVED_SHA256="$alpha_sha256"
  ALPHA_MINER_PACKAGE_LAYOUT="$alpha_layout"
  if [ -n "$alpha_sha256" ]; then
    ALPHA_MINER_CHECKSUM_URL=""
  else
    ALPHA_MINER_CHECKSUM_URL="${alpha_base_url}/SHA256SUMS"
  fi
}
