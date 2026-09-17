#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../scripts/alpha-miner-package.sh
source "$repo_dir/scripts/alpha-miner-package.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  local expected="$1" actual="$2" label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label: expected '$expected', got '$actual'"
}

test_current_pool_package() {
  alpha_miner_resolve_package "1.9.6" auto auto auto

  assert_equal "AlphaMiner-Linux-1.9.6-unified.tar.gz" "$ALPHA_MINER_RESOLVED_ASSET" "current asset"
  assert_equal "https://pearl.alphapool.tech/releases/AlphaMiner-Linux-1.9.6-unified.tar.gz" "$ALPHA_MINER_PACKAGE_URL" "current URL"
  assert_equal "cf231c87e405b2d8ccada41974633531874138662bf7219e8236c261261e46eb" "$ALPHA_MINER_RESOLVED_SHA256" "current SHA-256"
  assert_equal "unified-tar" "$ALPHA_MINER_PACKAGE_LAYOUT" "current layout"
  assert_equal "" "$ALPHA_MINER_CHECKSUM_URL" "current external checksum URL"
}

test_previous_github_package() {
  alpha_miner_resolve_package "1.9.5.2" auto auto auto

  assert_equal "AlphaMiner-Linux-1.9.5.2.run" "$ALPHA_MINER_RESOLVED_ASSET" "previous asset"
  assert_equal "https://github.com/AlphaMine-Tech/alpha-miner/releases/download/v1.9.5.2/AlphaMiner-Linux-1.9.5.2.run" "$ALPHA_MINER_PACKAGE_URL" "previous URL"
  assert_equal "" "$ALPHA_MINER_RESOLVED_SHA256" "previous pinned SHA-256"
  assert_equal "self-extracting" "$ALPHA_MINER_PACKAGE_LAYOUT" "previous layout"
  assert_equal "https://github.com/AlphaMine-Tech/alpha-miner/releases/download/v1.9.5.2/SHA256SUMS" "$ALPHA_MINER_CHECKSUM_URL" "previous checksum URL"
}

test_explicit_overrides() {
  alpha_miner_resolve_package "1.9.6" "custom.tar.gz" "https://example.test/miners" "abc123"

  assert_equal "custom.tar.gz" "$ALPHA_MINER_RESOLVED_ASSET" "override asset"
  assert_equal "https://example.test/miners/custom.tar.gz" "$ALPHA_MINER_PACKAGE_URL" "override URL"
  assert_equal "abc123" "$ALPHA_MINER_RESOLVED_SHA256" "override SHA-256"
}

test_current_pool_package
test_previous_github_package
test_explicit_overrides
printf 'package config tests passed\n'
