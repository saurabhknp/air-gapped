#!/usr/bin/env bash
# Stop llama-server started by start-llama-server.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$ROOT/.codex/llama-server.pid"
stopped=""
if [[ -r "$PID_FILE" ]]; then
  pid=$(cat "$PID_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    stopped="$pid"
  fi
  rm -f "$PID_FILE"
fi
if [[ -z "$stopped" ]]; then
  if [[ -f "$ROOT/.codex/model_info" ]]; then
    source "$ROOT/.codex/model_info"
    pids=$(pgrep -f "llama-server.*$MODEL_DIR" 2>/dev/null || true)
  else
    pids=$(pgrep -f "llama-server.*$ROOT/models" 2>/dev/null || true)
  fi
  if [[ -n "$pids" ]]; then
    for p in $pids; do kill "$p" 2>/dev/null || true; done
    stopped="$pids"
  fi
fi
if [[ -n "$stopped" ]]; then
  echo "Stopped llama-server (PID(s): $stopped)."
else
  echo "No llama-server process found for this project." >&2
fi
