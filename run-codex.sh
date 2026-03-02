#!/usr/bin/env bash
# Run Codex CLI with CODEX_HOME and local llama.cpp server config (.codex/config.toml). Ensure start-llama-server.sh is running first.
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
if [[ "${1:-}" == "exec" ]]; then
  # Check codex-proxy (port 28081), not llama.cpp directly
  PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
  if ! curl -sf "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1; then
    echo "Codex proxy not reachable at port $PROXY_PORT." >&2
    echo "Start the backend in another terminal and leave it open: ./start.sh (or ./start-llama-server.sh / ./start-vllm.sh)" >&2
    exit 1
  fi
  shift
  exec codex exec --skip-git-repo-check "$@"
fi
exec codex "$@"
