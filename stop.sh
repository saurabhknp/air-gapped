#!/usr/bin/env bash
# Unified stop: stop vLLM (GPU) and/or llama-server (CPU). Safe to run even if only one was running.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/stop-vllm.sh"
"$ROOT/stop-llama-server.sh"
