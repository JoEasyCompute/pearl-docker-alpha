#!/usr/bin/env bash
set -Eeuo pipefail

: "${PEARL_ADDRESS:?Set PEARL_ADDRESS to your prl1... wallet address in the Vast template environment}"

log_file="${PEARL_LOG_FILE:-/var/log/pearl-miner.log}"

if pgrep -f 'alpha-miner .*--worker' >/dev/null 2>&1; then
  echo "alpha-miner is already running"
  exit 0
fi

nohup /usr/local/bin/pearl-entrypoint >"$log_file" 2>&1 &
echo "Started Pearl miner as PID $!. Logs: $log_file"
