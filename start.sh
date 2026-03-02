#!/usr/bin/env bash
# Unified start: use vLLM (GPU) if configured, else llama-server (CPU). Keep this terminal open; run Codex in another.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -f "$ROOT/.codex/model_info" ]]; then
  echo "No .codex/model_info. Run ./bootstrap.sh first (on a machine with internet)." >&2
  echo "If this machine has no network, run ./bootstrap.sh on a connected machine, then copy the whole project folder here and run ./start.sh again." >&2
  exit 1
fi
# Use vLLM if bootstrap was done with USE_VLLM=1 (VLLM_MODEL set in model_info)
source "$ROOT/.codex/model_info"
if [[ -n "${VLLM_MODEL:-}" ]]; then
  exec "$ROOT/start-vllm.sh"
else
  exec "$ROOT/start-llama-server.sh"
fi
