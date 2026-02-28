# Source this before running Codex so it uses local vLLM and this directory's .codex as CODEX_HOME.
# Official: CODEX_HOME = where Codex stores config.toml, sessions, history (default ~/.codex).
# https://developers.openai.com/codex/config-advanced#config-and-state-locations
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export CODEX_HOME="$ROOT/.codex"
export VLLM_PORT="${VLLM_PORT:-28080}"
export OPENAI_API_BASE="${OPENAI_API_BASE:-http://127.0.0.1:${VLLM_PORT}/v1}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-EMPTY}"
