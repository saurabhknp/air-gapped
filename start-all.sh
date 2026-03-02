#!/bin/bash
# Start llama-server + codex-proxy together
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# Ports
LLAMA_PORT="${LLAMA_PORT:-28080}"
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
CTX="${LLAMA_CTX_SIZE:-8192}"

# Check if already running
if ss -tlnp 2>/dev/null | grep -q ":$LLAMA_PORT "; then
  echo "llama-server already running on port $LLAMA_PORT"
else
  echo "=== Starting llama-server on port $LLAMA_PORT ==="

  # Load model info
  source "$ROOT/.codex/model_info"

  # Find GGUF
  GGUF_PATH=$(find "$MODEL_DIR" -maxdepth 1 -name "*.gguf" -print -quit 2>/dev/null || true)
  [[ -z "$GGUF_PATH" ]] && { echo "No .gguf in $MODEL_DIR"; exit 1; }

  # Start llama-server
  "$LLAMA_SERVER" -m "$GGUF_PATH" --host 127.0.0.1 --port "$LLAMA_PORT" -c "$CTX" -t "$(nproc)" &
  echo $! > "$ROOT/.codex/llama-server.pid"
  echo "Started llama-server (PID $(cat "$ROOT/.codex/llama-server.pid"))"

  # Wait for ready
  echo -n "Waiting for llama-server"
  for i in {1..30}; do
    if curl -sf "http://127.0.0.1:$LLAMA_PORT/v1/models" >/dev/null 2>&1; then
      echo " OK"
      break
    fi
    echo -n "."
    sleep 1
  done
fi

# Start codex-proxy
if ss -tlnp 2>/dev/null | grep -q ":$PROXY_PORT "; then
  echo "codex-proxy already running on port $PROXY_PORT"
else
  echo ""
  echo "=== Starting codex-proxy on port $PROXY_PORT ==="
  LISTEN_ADDR=":$PROXY_PORT" UPSTREAM_URL="http://127.0.0.1:$LLAMA_PORT/v1" \
    "$ROOT/codex-proxy/codex-proxy" &
  echo $! > "$ROOT/.codex/codex-proxy.pid"
  sleep 1
  echo "Started codex-proxy (PID $(cat "$ROOT/.codex/codex-proxy.pid"))"
fi

echo ""
echo "=== Services Ready ==="
echo "llama-server: http://127.0.0.1:$LLAMA_PORT/v1"
echo "codex-proxy:  http://127.0.0.1:$PROXY_PORT/v1"
echo ""
echo "Configure .codex/config.toml:"
echo "  base_url = \"http://127.0.0.1:$PROXY_PORT/v1\""
echo ""
echo "Run codex:"
echo "  ./run-codex.sh exec \"your prompt\""
