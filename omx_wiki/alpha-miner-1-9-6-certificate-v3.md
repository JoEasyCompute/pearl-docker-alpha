---
title: "Alpha Miner 1.9.6 Certificate V3"
tags: ["alpha-miner", "pearl", "docker", "certificate-v3", "gpu"]
created: 2026-09-17T00:00:00.000Z
updated: 2026-09-17T00:00:00.000Z
sources: []
links: ["alpha-miner-1-9-5-2-migration.md"]
category: reference
confidence: high
schemaVersion: 1
---

# Alpha Miner 1.9.6 Certificate V3

## Why 1.9.6 Is Required

AlphaPool's live setup page states that certificate V3 is mandatory since Pearl block 99,000 and directs Linux users to `Alpha Miner 1.9.6 unified`. The GitHub repository still marks `v1.9.5.2` as its latest release, but that package repeatedly completed its GPU challenge and was then disconnected without registering a worker or share in the pool API.

## Package

- URL: `https://pearl.alphapool.tech/releases/AlphaMiner-Linux-1.9.6-unified.tar.gz`
- Observed and repository-pinned SHA-256: `cf231c87e405b2d8ccada41974633531874138662bf7219e8236c261261e46eb`
- The pool page does not publish a separate checksum file or qualification manifest beside the package.
- The archive contains its own `SHA256SUMS`; Docker and native installers verify both the pinned outer archive and every internally listed payload file.
- The embedded README labels the archive a public-test candidate, so fleet deployment requires a one-rig canary and a retained rollback image.

## Fleet Behavior

When `--gpu` is omitted, the launcher detects all supported visible GPUs. Unlike `v1.9.5.2`, `v1.9.6` appends `.gN` to each GPU worker identity before launching the cores. This prevents an eight-GPU host from opening multiple pool sessions under one identical worker name.

## Supported Paths

The launcher contains paths for compute capabilities 8.0 (CMP 170HX), 8.6, 8.9, 9.0 beta, and 12.0. RTX 5090 uses the Blackwell 12.0 core. The low-bandwidth H100 beta requires Ubuntu 24.04 / GLIBC 2.38 according to the embedded README; validate datacenter GPUs separately from the Ubuntu 22.04 RTX image.

## Related History

See [[alpha-miner-1-9-5-2-migration]] for the superseded package and CLI migration.
