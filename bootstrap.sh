#!/usr/bin/env bash
# One-click fetch of model, venv+vLLM, and Codex config. Run once on a machine with internet.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "[bootstrap] ROOT=$ROOT"

# 1. Dirs
mkdir -p "$ROOT/models"
echo "[bootstrap] Created models/"

# 2. Venv
if [[ ! -d "$ROOT/.venv" ]]; then
  uv venv "$ROOT/.venv" --python 3.12
  echo "[bootstrap] Created .venv"
fi
# Install deps (idempotent)
export VIRTUAL_ENV="$ROOT/.venv"
export PATH="$ROOT/.venv/bin:$PATH"
uv pip install --quiet huggingface_hub
uv pip install --quiet vllm
# Optional: vLLM with specific CUDA/ROCm: uv pip install --quiet vllm --torch-backend=auto
echo "[bootstrap] Venv ready (huggingface_hub, vllm)"

# 3. Model
MODEL_DIR="$ROOT/models/Nanbeige4.1-3B"
if [[ ! -d "$MODEL_DIR" ]] || [[ -z "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]]; then
  echo "[bootstrap] Downloading Nanbeige/Nanbeige4.1-3B ..."
  "$ROOT/.venv/bin/python" scripts/download_model.py "$ROOT"
else
  echo "[bootstrap] Model already present at $MODEL_DIR"
fi

# 4. Codex config (proxy provider + default model for local vLLM)
mkdir -p "$ROOT/.codex"
[[ -f "$ROOT/scripts/codex-config.toml.template" ]] || { echo "[bootstrap] ERROR: scripts/codex-config.toml.template not found." >&2; exit 1; }
PORT="${VLLM_PORT:-28080}"
sed "s/__VLLM_PORT__/$PORT/g" "$ROOT/scripts/codex-config.toml.template" > "$ROOT/.codex/config.toml"
echo "[bootstrap] .codex/config.toml installed (model_provider=proxy, port=$PORT)"

echo "[bootstrap] Done. Copy this directory to air-gapped hosts; run ./start-vllm.sh then ./run-codex.sh"
