# Manual Fallback: Mining On Your Own Idle Vast Hosts

Prefer a Vast provider default job for machines you own and have listed on Vast. Use this manual Docker method only if you cannot configure a default job.

Do not run this miner on GPUs that are rented by a customer. With this manual method, you are responsible for stopping the container before the machine is made available to renters.

## Direct Docker Run

SSH into the host and run:

```bash
docker pull YOUR_DOCKERHUB_OR_GHCR_IMAGE:1.7.9

docker rm -f pearl-miner 2>/dev/null || true

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

Stop mining before making the machine available to customers:

```bash
docker rm -f pearl-miner
```

## Sanity Checks

```bash
nvidia-smi
docker ps --filter name=pearl-miner
docker logs --tail 100 pearl-miner
```

The pool dashboard should show workers as `prl1pYOUR_PRL_ADDRESS.<hostname>-pearl`.
