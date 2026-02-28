#!/usr/bin/env bash
# Start vLLM serving Nanbeige4.1-3B. Run in one terminal; then use run-codex.sh in another.
# Default port 28080 to avoid conflicts. Override with VLLM_PORT if needed.
#
# OOM avoidance (see docs.vllm.ai configuration/engine_args):
#   --max-model-len auto   : vLLM picks the largest context length that fits in GPU memory.
#   --gpu-memory-utilization : Fraction of GPU memory to use (default 0.85). Lower if OOM.
# Override: VLLM_GPU_MEMORY_UTILIZATION=0.75 ./start-vllm.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${VLLM_PORT:-28080}"
GPU_UTIL="${VLLM_GPU_MEMORY_UTILIZATION:-0.85}"
MODEL_DIR="$ROOT/models/Nanbeige4.1-3B"
if [[ ! -d "$MODEL_DIR" ]]; then
  echo "Model not found at $MODEL_DIR. Run ./bootstrap.sh first (on a machine with internet)." >&2
  exit 1
fi
if [[ ! -x "$ROOT/.venv/bin/vllm" ]]; then
  echo "vLLM not found. Run ./bootstrap.sh first." >&2
  exit 1
fi
if (echo >/dev/tcp/127.0.0.1/"$PORT") 2>/dev/null; then
  echo "Port $PORT is already in use. Try: VLLM_PORT=$((PORT+1)) ./start-vllm.sh" >&2
  echo "Then run Codex with: VLLM_PORT=$((PORT+1)) ./run-codex.sh ..." >&2
  exit 1
fi
PID_FILE="$ROOT/.codex/vllm.pid"
if [[ -r "$PID_FILE" ]]; then
  old_pid=$(cat "$PID_FILE")
  if kill -0 "$old_pid" 2>/dev/null; then
    echo "vLLM already running (PID $old_pid). Stop it with: ./stop-vllm.sh" >&2
    exit 1
  fi
  rm -f "$PID_FILE"
fi
mkdir -p "$ROOT/.codex"
"$ROOT/.venv/bin/vllm" serve "$MODEL_DIR" \
  --trust-remote-code \
  --host 127.0.0.1 \
  --port "$PORT" \
  --max-model-len auto \
  --gpu-memory-utilization "$GPU_UTIL" \
  --served-model-name Nanbeige4.1-3B &
vllm_pid=$!
echo "$vllm_pid" > "$PID_FILE"
trap 'kill "$vllm_pid" 2>/dev/null; rm -f "$PID_FILE"; exit' INT TERM
wait "$vllm_pid"
rm -f "$PID_FILE"
