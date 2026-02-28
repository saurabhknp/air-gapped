#!/usr/bin/env bash
# Run Codex CLI with CODEX_HOME and local vLLM config (.codex/config.toml). Ensure start-vllm.sh is running first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/env.sh"
if ! command -v codex &>/dev/null; then
  echo "Codex CLI not found on PATH. Install from Cursor: Preferences -> Advanced -> Install CLI" >&2
  exit 1
fi
if [[ ! -f "$ROOT/.codex/config.toml" ]]; then
  echo ".codex/config.toml not found. Run ./bootstrap.sh first." >&2
  exit 1
fi
# Preflight: when running exec, check vLLM is reachable to avoid confusing Codex errors
if [[ "${1:-}" == "exec" ]]; then
  PORT="${VLLM_PORT:-28080}"
  if ! curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
    echo "vLLM is not reachable at port $PORT. Start it with: ./start-vllm.sh" >&2
    exit 1
  fi
  shift
  exec codex exec --skip-git-repo-check "$@"
fi
exec codex "$@"
