#!/usr/bin/env bash
# Full detection: start llama-server, API, Codex exec, stop, and failure-path checks.
# Run from project root. Requires: make deps already run, codex on PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PORT="${LLAMA_PORT:-28080}"
FAILED=0

run() {
  echo "--- $*"
  if ( set +e; "$@"; ); then echo "  OK"; else echo "  FAIL"; FAILED=1; fi
}

# 1) Preflight: config and server not already running
if [[ ! -f "$ROOT/.codex/config.toml" ]]; then
  echo "Run make deps first."
  exit 1
fi
if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
  echo "Model server already running on port $PORT. Stop it with ./stop-llama-server.sh then re-run."
  exit 1
fi

# 2) Start llama-server
echo "--- Starting llama-server..."
START_TIMEOUT="${LLAMA_START_TIMEOUT:-120}"
mkdir -p "$ROOT/.codex"
./start-llama-server.sh > "$ROOT/.codex/llama-server.log" 2>&1 &
SERVER_PID=$!
cleanup() { kill $SERVER_PID 2>/dev/null; ./stop-llama-server.sh 2>/dev/null; }
trap cleanup EXIT

# 3) Wait for ready
echo "Waiting for model server (timeout ${START_TIMEOUT}s)..."
for i in $(seq 1 "$START_TIMEOUT"); do
  if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
    echo "  Server ready at ${i}s"
    break
  fi
  sleep 1
  if [[ $i -eq "$START_TIMEOUT" ]]; then
    echo "  Server did not become ready in ${START_TIMEOUT}s. Last log lines:"
    tail -20 "$ROOT/.codex/llama-server.log" 2>/dev/null || true
    exit 1
  fi
done

# 4) API test
run ./test-api.sh

# 5) Codex exec (if codex on PATH; optional: llama-server may return 400 for tool schema)
if command -v codex &>/dev/null; then
  if ./run-codex.sh exec "echo test-ok" 2>&1 | tee /tmp/codex_exec_out.txt; then
    echo "  OK"
  else
    if grep -q "type.*must be.*function" /tmp/codex_exec_out.txt 2>/dev/null; then
      echo "  SKIP (known API compatibility: tool type)"
    else
      echo "  FAIL"
      FAILED=1
    fi
  fi
else
  echo "--- codex not on PATH; skipping Codex exec test"
fi

# 6) Stop
./stop-llama-server.sh
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 || break
  sleep 2
done
sleep 2
trap - EXIT

# 7) Failure paths (ensure server is fully stopped)
echo "--- Failure-path checks..."
_offline_out=$(./run-codex.sh exec "x" 2>&1) || true
if echo "$_offline_out" | grep -qE "not reachable|Connection refused"; then
  echo "  run-codex exec without server: OK"
else
  echo "  run-codex exec without server: FAIL"
  FAILED=1
fi
mv "$ROOT/.codex/config.toml" "$ROOT/.codex/config.toml.bak" 2>/dev/null || true
_config_out=$(./run-codex.sh --help 2>&1) || true
if echo "$_config_out" | grep -q "config.toml not found"; then
  echo "  run-codex without config: OK"
else
  echo "  run-codex without config: FAIL"
  FAILED=1
fi
mv "$ROOT/.codex/config.toml.bak" "$ROOT/.codex/config.toml" 2>/dev/null || true

if [[ $FAILED -eq 0 ]]; then
  echo "All checks passed."
else
  echo "Some checks failed."
  exit 1
fi
