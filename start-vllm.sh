#!/usr/bin/env bash
# Start vLLM serving the model chosen at bootstrap. Run in one terminal; then use run-codex.sh in another.
#
# Override env:
#   VLLM_PORT (default 28080)
#   VLLM_DEVICE=cpu|cuda (default cpu). Set to "cuda" if you have a GPU.
#   VLLM_GPU_MEMORY_UTILIZATION (default 0.85). OOM: try 0.75 or set VLLM_MAX_MODEL_LEN=4096.
#
# CPU-only (when VLLM_DEVICE=cpu):
#   VLLM_CPU_NUM_THREADS  — number of CPU threads (exported as OMP_NUM_THREADS). Unset = auto-detect (all logical CPUs).
#   VLLM_CPU_KVCACHE_SPACE — KV cache size in GiB. Unset = auto-detect (~50%% of total RAM, at least 2 GiB).
#   VLLM_MAX_MODEL_LEN    — max context length (default 4096 for CPU).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${VLLM_PORT:-28080}"
GPU_UTIL="${VLLM_GPU_MEMORY_UTILIZATION:-0.85}"
VLLM_DEVICE="${VLLM_DEVICE:-cpu}"
if [[ ! -f "$ROOT/.codex/model_info" ]]; then
  echo "No .codex/model_info. Run ./bootstrap.sh first." >&2
  exit 1
fi
# If user asks for GPU but env was bootstrapped CPU-only, warn
if [[ "${VLLM_DEVICE:-}" == "cuda" ]] && [[ -r "$ROOT/.codex/install_mode" ]] && [[ "$(cat "$ROOT/.codex/install_mode" 2>/dev/null)" == "0" ]]; then
  echo "Warning: This project was bootstrapped for CPU-only (no CUDA). To use GPU, run: VLLM_USE_GPU=1 ./bootstrap.sh" >&2
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
# CPU: hide GPUs and apply CPU-related env (thread count, KV cache size)
if [[ "$VLLM_DEVICE" == "cpu" ]]; then
  export CUDA_VISIBLE_DEVICES=""
  # Auto-detect CPU count and RAM when not set (target: CPU-only / air-gapped servers)
  if [[ -z "${VLLM_CPU_NUM_THREADS:-}" ]]; then
    if command -v nproc &>/dev/null; then
      VLLM_CPU_NUM_THREADS=$(nproc)
    elif command -v getconf &>/dev/null; then
      VLLM_CPU_NUM_THREADS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_CONF 2>/dev/null || echo 1)
    else
      [[ "$(uname -s)" == "Darwin" ]] && VLLM_CPU_NUM_THREADS=$(sysctl -n hw.ncpu 2>/dev/null) || VLLM_CPU_NUM_THREADS=1
    fi
    export OMP_NUM_THREADS="${VLLM_CPU_NUM_THREADS:-1}"
  else
    export OMP_NUM_THREADS="$VLLM_CPU_NUM_THREADS"
  fi
  if [[ -z "${VLLM_CPU_KVCACHE_SPACE:-}" ]]; then
    TOTAL_GIB=4
    if [[ -r /proc/meminfo ]]; then
      TOTAL_KB=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
      [[ -n "$TOTAL_KB" ]] && TOTAL_GIB=$((TOTAL_KB / 1024 / 1024))
    elif [[ "$(uname -s)" == "Darwin" ]]; then
      TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
      [[ -n "$TOTAL_BYTES" ]] && TOTAL_GIB=$((TOTAL_BYTES / 1024 / 1024 / 1024))
    fi
    # Use ~50% of total RAM for KV cache, at least 2 GiB
    VLLM_CPU_KVCACHE_SPACE=$((TOTAL_GIB / 2))
    [[ "$VLLM_CPU_KVCACHE_SPACE" -lt 2 ]] && VLLM_CPU_KVCACHE_SPACE=2
    export VLLM_CPU_KVCACHE_SPACE
  fi
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
