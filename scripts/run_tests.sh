#!/usr/bin/env bash
# Full detection: GPU inference, API, Codex exec, stop, and failure-path checks.
# Run from project root. Requires: make deps already run, codex on PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PORT="${VLLM_PORT:-28080}"
FAILED=0

run() {
  echo "--- $*"
  if ( set +e; "$@"; ); then echo "  OK"; else echo "  FAIL"; FAILED=1; fi
}

# 1) Preflight: config and vLLM not already running
if [[ ! -f "$ROOT/.codex/config.toml" ]]; then
  echo "Run make deps first."
  exit 1
fi
if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
  echo "vLLM already running on port $PORT. Stop it with ./stop-vllm.sh then re-run."
  exit 1
fi

# 2) Start vLLM (GPU, default model)
echo "--- Starting vLLM (GPU)..."
./start-vllm.sh &
VLLM_PID=$!
cleanup() { kill $VLLM_PID 2>/dev/null; ./stop-vllm.sh 2>/dev/null; }
trap cleanup EXIT

# 3) Wait for ready
echo "Waiting for vLLM..."
for i in $(seq 1 24); do
  sleep 5
  if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
    echo "  vLLM ready at ${i}0s"
    break
  fi
  [[ $i -eq 24 ]] && { echo "  vLLM did not become ready"; exit 1; }
done

# 4) API test
run ./test-vllm-api.sh

# 5) Codex exec (if codex on PATH)
if command -v codex &>/dev/null; then
  run ./run-codex.sh exec "echo test-ok"
else
  echo "--- codex not on PATH; skipping Codex exec test"
fi

# 6) Stop
./stop-vllm.sh
# Wait until port is closed so preflight in run-codex fails
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 || break
  sleep 2
done
trap - EXIT

# 7) Failure paths
echo "--- Failure-path checks..."
if ./run-codex.sh exec "x" 2>&1 | grep -q "vLLM is not reachable"; then
  echo "  run-codex exec without vLLM: OK"
else
  echo "  run-codex exec without vLLM: FAIL"
  FAILED=1
fi
mv "$ROOT/.codex/config.toml" "$ROOT/.codex/config.toml.bak" 2>/dev/null || true
if ./run-codex.sh --help 2>&1 | grep -q "config.toml not found"; then
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
