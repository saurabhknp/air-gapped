#!/usr/bin/env bash
# Quick test that vLLM API responds. Run while start-vllm.sh is running.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/env.sh"
PORT="${VLLM_PORT:-28080}"
if ! curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
  echo "Cannot reach vLLM at http://127.0.0.1:$PORT. Start it with: ./start-vllm.sh" >&2
  exit 1
fi
echo "Listing models (GET http://127.0.0.1:$PORT/v1/models)..."
curl -s "http://127.0.0.1:$PORT/v1/models" | head -50
echo ""
echo "Chat completion (POST /v1/chat/completions)..."
curl -sf "http://127.0.0.1:$PORT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Nanbeige4.1-3B",
    "messages": [{"role": "user", "content": "hi"}],
    "max_tokens": 64
  }' | head -20
echo ""
