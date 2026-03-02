#!/usr/bin/env bash
# Start vLLM (GPU) server + codex-proxy. Use when GPU is available for faster inference.
# Requires: bootstrap with USE_VLLM=1 (e.g. USE_VLLM=1 ./bootstrap.sh).
# Override: VLLM_PORT (default 28080), CODEX_PROXY_PORT (default 28081).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
source "$ROOT/env.sh" 2>/dev/null || true

PORT="${VLLM_PORT:-${LLAMA_PORT:-28080}}"
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"

if [[ ! -f "$ROOT/.codex/model_info" ]]; then
  echo "No .codex/model_info. Run ./bootstrap.sh first." >&2
  exit 1
fi
source "$ROOT/.codex/model_info"

if [[ -z "${VLLM_MODEL:-}" ]]; then
  echo "VLLM_MODEL not set in .codex/model_info. Run bootstrap with USE_VLLM=1: USE_VLLM=1 ./bootstrap.sh" >&2
  exit 1
fi

if ! "$ROOT/.venv/bin/python" -c "import vllm" 2>/dev/null; then
  echo "vLLM not installed. Run: USE_VLLM=1 ./bootstrap.sh" >&2
  exit 1
fi

if (echo >/dev/tcp/127.0.0.1/"$PORT") 2>/dev/null; then
  echo "Port $PORT already in use. Try: VLLM_PORT=$((PORT+1)) ./start-vllm.sh" >&2
  exit 1
fi

VLLM_PID_FILE="$ROOT/.codex/vllm-server.pid"
PROXY_PID_FILE="$ROOT/.codex/codex-proxy.pid"
if [[ -r "$VLLM_PID_FILE" ]]; then
  old_pid=$(cat "$VLLM_PID_FILE")
  if kill -0 "$old_pid" 2>/dev/null; then
    echo "vLLM already running (PID $old_pid). Stop with: ./stop-vllm.sh" >&2
    exit 1
  fi
  rm -f "$VLLM_PID_FILE"
fi
mkdir -p "$ROOT/.codex"

# Use Codex config model name for vLLM so requests match
MODEL_FOR_REQUEST="${VLLM_SERVED_NAME:-$VLLM_MODEL}"
# Point Codex config at the vLLM model name so requests match vLLM's served model
if [[ -f "$ROOT/.codex/config.toml" ]]; then
  sed -i.bak "s/^model = .*/model = \"$MODEL_FOR_REQUEST\"/" "$ROOT/.codex/config.toml" 2>/dev/null || true
fi

# Defaults: 1 concurrent, 100k context (102400 tokens), use most VRAM (0.95). Override with VLLM_EXTRA_ARGS if OOM or model caps lower.
VLLM_EXTRA_ARGS="${VLLM_EXTRA_ARGS:-}"
EXTRA=()
[[ -n "$VLLM_EXTRA_ARGS" ]] && read -ra EXTRA <<< "$VLLM_EXTRA_ARGS"
echo "Starting vLLM (GPU) on port $PORT with model: $VLLM_MODEL (max 1 concurrent, 100k context, gpu_memory_utilization=0.95)"
"$ROOT/.venv/bin/vllm" serve "$VLLM_MODEL" \
  --host 127.0.0.1 \
  --port "$PORT" \
  --served-model-name "$MODEL_FOR_REQUEST" \
  --max-num-seqs 1 \
  --max-model-len 102400 \
  --gpu-memory-utilization 0.95 \
  "${EXTRA[@]}" \
  &
vllm_pid=$!
echo "$vllm_pid" > "$VLLM_PID_FILE"
trap 'kill "$vllm_pid" 2>/dev/null; rm -f "$VLLM_PID_FILE"; exit' INT TERM

# Wait for vLLM to be ready
echo -n "Waiting for vLLM"
for i in $(seq 1 120); do
  if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
    echo " OK"
    break
  fi
  echo -n "."
  sleep 1
  if [[ $i -eq 120 ]]; then
    echo " timeout"
    kill "$vllm_pid" 2>/dev/null || true
    rm -f "$VLLM_PID_FILE"
    exit 1
  fi
done

# Start codex-proxy
PROXY_BIN="$ROOT/codex-proxy/codex-proxy"
if [[ -x "$PROXY_BIN" ]]; then
  echo "Starting codex-proxy on port $PROXY_PORT..."
  LISTEN_ADDR=":$PROXY_PORT" UPSTREAM_URL="http://127.0.0.1:$PORT/v1" "$PROXY_BIN" &
  proxy_pid=$!
  echo "$proxy_pid" > "$PROXY_PID_FILE"
  trap 'kill "$proxy_pid" 2>/dev/null; kill "$vllm_pid" 2>/dev/null; rm -f "$VLLM_PID_FILE" "$PROXY_PID_FILE"; exit' INT TERM
  echo ""
  echo "vLLM:      http://127.0.0.1:$PORT/v1"
  echo "codex-proxy: http://127.0.0.1:$PROXY_PORT/v1"
  echo "Run: ./run-codex.sh exec \"your prompt\""
  echo ""
fi

wait "$vllm_pid"
rm -f "$VLLM_PID_FILE" "$PROXY_PID_FILE"
