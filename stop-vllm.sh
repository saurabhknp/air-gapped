#!/usr/bin/env bash
# Stop vLLM server started by start-vllm.sh (uses .codex/vllm.pid when set by start-vllm.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$ROOT/.codex/vllm.pid"
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
  MODEL_DIR="$ROOT/models/Nanbeige4.1-3B"
  pids=$(pgrep -f "vllm serve.*$MODEL_DIR" 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    for p in $pids; do kill "$p" 2>/dev/null || true; done
    stopped="$pids"
  fi
fi
if [[ -n "$stopped" ]]; then
  echo "Stopped vLLM (PID(s): $stopped)."
else
  echo "No vLLM process found for this project." >&2
fi
