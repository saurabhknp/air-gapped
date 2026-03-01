# Source this before running Codex so it uses local llama.cpp server and this directory's .codex as CODEX_HOME.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export CODEX_HOME="$ROOT/.codex"
export LLAMA_PORT="${LLAMA_PORT:-28080}"
export OPENAI_API_BASE="${OPENAI_API_BASE:-http://127.0.0.1:${LLAMA_PORT}/v1}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-EMPTY}"
