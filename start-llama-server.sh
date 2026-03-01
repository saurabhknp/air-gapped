#!/usr/bin/env bash
# Start llama.cpp server (CPU only) for the model chosen at bootstrap. Keep terminal open; use run-codex.sh in another.
#
# Override: LLAMA_PORT (default 28080), LLAMA_CTX_SIZE (default 4096), LLAMA_THREADS (unset = auto).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${LLAMA_PORT:-28080}"
if [[ ! -f "$ROOT/.codex/model_info" ]]; then
  echo "No .codex/model_info. Run ./bootstrap.sh first." >&2
  exit 1
fi
source "$ROOT/.codex/model_info"
if [[ ! -d "$MODEL_DIR" ]]; then
  echo "Model not found at $MODEL_DIR. Run ./bootstrap.sh first." >&2
  exit 1
fi
if [[ ! -x "${LLAMA_SERVER:-}" ]]; then
  echo "llama-server not found. Run ./bootstrap.sh first." >&2
  exit 1
fi
if (echo >/dev/tcp/127.0.0.1/"$PORT") 2>/dev/null; then
  echo "Port $PORT is already in use. Try: LLAMA_PORT=$((PORT+1)) ./start-llama-server.sh" >&2
  exit 1
fi
PID_FILE="$ROOT/.codex/llama-server.pid"
if [[ -r "$PID_FILE" ]]; then
  old_pid=$(cat "$PID_FILE")
  if kill -0 "$old_pid" 2>/dev/null; then
    echo "llama-server already running (PID $old_pid). Stop it with: ./stop-llama-server.sh" >&2
    exit 1
  fi
  rm -f "$PID_FILE"
fi
mkdir -p "$ROOT/.codex"

GGUF_PATH=""
if compgen -G "$MODEL_DIR/*.gguf" >/dev/null 2>&1; then
  GGUF_PATH="$(find "$MODEL_DIR" -maxdepth 1 -name "*.gguf" -print -quit)"
fi
[[ -z "$GGUF_PATH" ]] && { echo "No .gguf file in $MODEL_DIR" >&2; exit 1; }

CTX="${LLAMA_CTX_SIZE:-4096}"
THREADS_ARG=()
if [[ -n "${LLAMA_THREADS:-}" ]]; then
  THREADS_ARG=(-t "$LLAMA_THREADS")
else
  if command -v nproc &>/dev/null; then
    THREADS_ARG=(-t "$(nproc)")
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    THREADS_ARG=(-t "$(sysctl -n hw.ncpu 2>/dev/null || echo 4)")
  fi
fi

"$LLAMA_SERVER" -m "$GGUF_PATH" --host 127.0.0.1 --port "$PORT" -c "$CTX" "${THREADS_ARG[@]}" &
svr_pid=$!
echo "$svr_pid" > "$PID_FILE"
trap 'kill "$svr_pid" 2>/dev/null; rm -f "$PID_FILE"; exit' INT TERM
wait "$svr_pid"
rm -f "$PID_FILE"
