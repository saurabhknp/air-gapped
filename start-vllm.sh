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
  echo "No .codex/model_info. Run ./bootstrap.sh first (on a machine with internet)." >&2
  echo "If this machine has no network, run ./bootstrap.sh on a connected machine, then copy the whole project folder here and run ./start.sh again." >&2
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

# Auto-detect GPU memory and set max-model-len accordingly (override: VLLM_MAX_MODEL_LEN)
GPU_MEM_UTIL="${VLLM_GPU_MEM_UTIL:-0.95}"
MAX_SEQS="${VLLM_MAX_NUM_SEQS:-1}"
if [[ -n "${VLLM_MAX_MODEL_LEN:-}" ]]; then
  MAX_LEN_ARG=(--max-model-len "$VLLM_MAX_MODEL_LEN")
else
  # Let vLLM auto-detect from GPU memory; it will pick the largest context that fits
  MAX_LEN_ARG=()
fi

# GGUF models need explicit tokenizer path (no tokenizer in the GGUF repo)
TOKENIZER_ARG=()
if [[ -n "${VLLM_TOKENIZER:-}" ]] && [[ -d "${VLLM_TOKENIZER}" ]]; then
  TOKENIZER_ARG=(--tokenizer "$VLLM_TOKENIZER")
fi

VLLM_EXTRA_ARGS="${VLLM_EXTRA_ARGS:-}"
EXTRA=()
[[ -n "$VLLM_EXTRA_ARGS" ]] && read -ra EXTRA <<< "$VLLM_EXTRA_ARGS"
echo "Starting vLLM (GPU) on port $PORT with model: $VLLM_MODEL (max_seqs=$MAX_SEQS, gpu_mem=$GPU_MEM_UTIL, max_model_len=${VLLM_MAX_MODEL_LEN:-auto})"
"$ROOT/.venv/bin/vllm" serve "$VLLM_MODEL" \
  --host 127.0.0.1 \
  --port "$PORT" \
  --served-model-name "$MODEL_FOR_REQUEST" \
  --max-num-seqs "$MAX_SEQS" \
  --gpu-memory-utilization "$GPU_MEM_UTIL" \
  "${MAX_LEN_ARG[@]}" \
  "${TOKENIZER_ARG[@]}" \
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
  echo "To stop: Ctrl+C in this terminal, or run ./stop.sh in any terminal."
  echo ""
fi

wait "$vllm_pid"
rm -f "$VLLM_PID_FILE" "$PROXY_PID_FILE"
