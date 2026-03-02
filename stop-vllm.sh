#!/usr/bin/env bash
# Stop vLLM server and codex-proxy started by start-vllm.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
stopped=""

PROXY_PID_FILE="$ROOT/.codex/codex-proxy.pid"
if [[ -r "$PROXY_PID_FILE" ]]; then
  pid=$(cat "$PROXY_PID_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    stopped="${stopped:+$stopped }$pid"
  fi
  rm -f "$PROXY_PID_FILE"
fi

VLLM_PID_FILE="$ROOT/.codex/vllm-server.pid"
if [[ -r "$VLLM_PID_FILE" ]]; then
  pid=$(cat "$VLLM_PID_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    stopped="${stopped:+$stopped }$pid"
  fi
  rm -f "$VLLM_PID_FILE"
fi

if [[ -z "$stopped" ]]; then
  pids=$(pgrep -f "vllm.entrypoints.openai.api_server" 2>/dev/null || true)
  [[ -z "$pids" ]] && pids=$(pgrep -f "vllm serve" 2>/dev/null || true)
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
