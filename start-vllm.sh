#!/usr/bin/env bash
# Start vLLM serving the model chosen at bootstrap. Run in one terminal; then use run-codex.sh in another.
# Default port 28080. Override: VLLM_PORT, VLLM_DEVICE=cpu|cuda, VLLM_GPU_MEMORY_UTILIZATION.
#
# VLLM_DEVICE: "cuda" (default) or "cpu". For CPU, no GPU is used (slower).
# OOM: VLLM_GPU_MEMORY_UTILIZATION=0.75 or --max-model-len 4096 in script.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${VLLM_PORT:-28080}"
GPU_UTIL="${VLLM_GPU_MEMORY_UTILIZATION:-0.85}"
VLLM_DEVICE="${VLLM_DEVICE:-cuda}"
if [[ ! -f "$ROOT/.codex/model_info" ]]; then
  echo "No .codex/model_info. Run ./bootstrap.sh first." >&2
  exit 1
fi
source "$ROOT/.codex/model_info"
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
# CPU: hide GPUs so vLLM uses CPU backend
if [[ "$VLLM_DEVICE" == "cpu" ]]; then
  export CUDA_VISIBLE_DEVICES=""
fi
LOAD_FORMAT=""
VLLM_MODEL_PATH="$MODEL_DIR"
if compgen -G "$MODEL_DIR/*.gguf" >/dev/null 2>&1; then
  LOAD_FORMAT="--load-format gguf"
  # vLLM expects path to the .gguf file for GGUF, not the directory
  VLLM_MODEL_PATH="$(find "$MODEL_DIR" -maxdepth 1 -name "*.gguf" -print -quit)"
  [[ -z "$VLLM_MODEL_PATH" ]] && { echo "No .gguf file in $MODEL_DIR" >&2; exit 1; }
fi
# Cap context length so KV cache fits (model default can exceed GPU memory). Override: VLLM_MAX_MODEL_LEN.
MAX_LEN="${VLLM_MAX_MODEL_LEN:-32768}"
[[ "$VLLM_DEVICE" == "cpu" ]] || [[ -n "$LOAD_FORMAT" ]] && MAX_LEN="${VLLM_MAX_MODEL_LEN:-4096}"
VLLM_ARGS=(
  $LOAD_FORMAT
  --trust-remote-code
  --host 127.0.0.1
  --port "$PORT"
  --max-model-len "$MAX_LEN"
  --served-model-name "$SERVED_MODEL_NAME"
)
[[ "$VLLM_DEVICE" == "cuda" ]] && VLLM_ARGS+=(--gpu-memory-utilization "$GPU_UTIL")
"$ROOT/.venv/bin/vllm" serve "$VLLM_MODEL_PATH" "${VLLM_ARGS[@]}" &
vllm_pid=$!
echo "$vllm_pid" > "$PID_FILE"
trap 'kill "$vllm_pid" 2>/dev/null; rm -f "$PID_FILE"; exit' INT TERM
wait "$vllm_pid"
rm -f "$PID_FILE"
