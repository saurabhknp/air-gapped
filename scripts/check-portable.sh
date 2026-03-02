#!/usr/bin/env bash
# Check that the project folder has everything needed for a portable copy (before copying to air-gapped workspace).
# Run from project root: ./scripts/check-portable.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ok=0
missing=0
check() {
  if [[ -e "$1" ]]; then
    echo "OK   $1"
    ((ok++)) || true
  else
    echo "MISSING  $1"
    ((missing++)) || true
  fi
}
echo "Checking portable copy (run from project root)..."
check "models"
check ".venv"
check ".codex"
check "llama_bin"
if [[ -f "$ROOT/.codex/model_info" ]]; then
  check ".codex/model_info"
else
  echo "MISSING  .codex/model_info (run ./bootstrap.sh first)"
  ((missing++)) || true
fi
# codex-proxy: built binary or Go source so we can build after copy
if [[ -x "$ROOT/codex-proxy/codex-proxy" ]]; then
  echo "OK   codex-proxy (binary)"
  ((ok++)) || true
elif [[ -f "$ROOT/codex-proxy/main.go" ]]; then
  echo "OK   codex-proxy (source; run 'make proxy' after copy if needed)"
  ((ok++)) || true
else
  echo "MISSING  codex-proxy (binary or codex-proxy/main.go)"
  ((missing++)) || true
fi
echo ""
if [[ $missing -gt 0 ]]; then
  echo "Result: $missing item(s) missing. Copy may fail in air-gapped environment."
  exit 1
fi
echo "Result: all checked items present. Safe to copy folder to air-gapped workspace."
