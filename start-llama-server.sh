#!/usr/bin/env bash
# Start llama.cpp server (CPU only) for the model chosen at bootstrap. Keep terminal open; use run-codex.sh in another.
#
# Override: LLAMA_PORT (default 28080), LLAMA_CTX_SIZE (auto from RAM), LLAMA_THREADS (auto from nproc).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${LLAMA_PORT:-28080}"
if [[ ! -f "$ROOT/.codex/model_info" ]]; then
  echo "No .codex/model_info. Run ./bootstrap.sh first (on a machine with internet)." >&2
  echo "If this machine has no network, run ./bootstrap.sh on a connected machine, then copy the whole project folder here and run ./start.sh again." >&2
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

# Auto-detect context size from available RAM (override: LLAMA_CTX_SIZE)
if [[ -n "${LLAMA_CTX_SIZE:-}" ]]; then
  CTX="$LLAMA_CTX_SIZE"
else
  AVAIL_MB=8192
  if [[ -r /proc/meminfo ]]; then
    AVAIL_MB=$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    AVAIL_MB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 8589934592) / 1048576 ))
  fi
  if (( AVAIL_MB >= 65536 )); then
    CTX=32768
  elif (( AVAIL_MB >= 32768 )); then
    CTX=16384
  elif (( AVAIL_MB >= 16384 )); then
    CTX=8192
  elif (( AVAIL_MB >= 8192 )); then
    CTX=4096
  else
    CTX=2048
  fi
fi

# Auto-detect thread count (override: LLAMA_THREADS)
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

echo "Starting llama-server on port $PORT (ctx=$CTX, threads=${THREADS_ARG[1]:-auto}, model=$(basename "$GGUF_PATH"))"
"$LLAMA_SERVER" -m "$GGUF_PATH" --host 127.0.0.1 --port "$PORT" -c "$CTX" "${THREADS_ARG[@]}" &
svr_pid=$!
echo "$svr_pid" > "$PID_FILE"
PROXY_PID_FILE="$ROOT/.codex/codex-proxy.pid"
trap 'kill "$svr_pid" 2>/dev/null; rm -f "$PID_FILE"; exit' INT TERM

# Start Go codex-proxy (converts Responses API to Chat Completions)
# This fixes "tool type must be 'function'" errors from llama.cpp
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
PROXY_BIN="$ROOT/codex-proxy/codex-proxy"
if [[ -x "$PROXY_BIN" ]]; then
  echo "Starting codex-proxy on port $PROXY_PORT..."
  LISTEN_ADDR=":$PROXY_PORT" UPSTREAM_URL="http://127.0.0.1:$PORT/v1" "$PROXY_BIN" &
  proxy_pid=$!
  echo "$proxy_pid" > "$PROXY_PID_FILE"
  trap 'kill "$proxy_pid" 2>/dev/null; kill "$svr_pid" 2>/dev/null; rm -f "$PID_FILE" "$PROXY_PID_FILE"; exit' INT TERM
  echo ""
  echo "Codex proxy running at: http://127.0.0.1:$PROXY_PORT/v1"
  echo "Configure .codex/config.toml: base_url = \"http://127.0.0.1:$PROXY_PORT/v1\""
  echo "To stop: Ctrl+C in this terminal, or run ./stop.sh in any terminal."
  echo ""
fi

wait "$svr_pid"
rm -f "$PID_FILE" "$PROXY_PID_FILE"
