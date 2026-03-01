#!/usr/bin/env bash
# One-click fetch of model, venv+vLLM, and Codex config. Run once on a machine with internet.
# Default: CPU-only mode (minimal deps, no CUDA). For GPU: VLLM_USE_GPU=1 ./bootstrap.sh or ./bootstrap.sh gpu
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "[bootstrap] ROOT=$ROOT"

# GPU mode only if user explicitly opts in
USE_GPU=
case "${1:-}" in
  gpu|gpu-only) USE_GPU=1 ;;
  *)            [[ -n "${VLLM_USE_GPU:-}" ]] && [[ "${VLLM_USE_GPU}" != "0" ]] && USE_GPU=1 ;;
esac

# 1. Dirs
mkdir -p "$ROOT/models"
echo "[bootstrap] Created models/"

# 2. Venv
if [[ ! -d "$ROOT/.venv" ]]; then
  uv venv "$ROOT/.venv" --python 3.12
  echo "[bootstrap] Created .venv"
fi
export VIRTUAL_ENV="$ROOT/.venv"
export PATH="$ROOT/.venv/bin:$PATH"

# Install deps: default = CPU-only (minimal: PyTorch CPU + vLLM, no CUDA). GPU = full vLLM stack.
if [[ -n "$USE_GPU" ]]; then
  echo "[bootstrap] GPU mode: installing full vLLM stack (CUDA deps)..."
  uv pip install --quiet "huggingface_hub>=0.20.0" "vllm>=0.16.0"
  echo "[bootstrap] Venv ready (huggingface_hub, vllm with CUDA)"
else
  echo "[bootstrap] CPU-only mode: installing minimal deps (no CUDA)..."
  # PyTorch CPU-only first so vLLM does not pull torch+CUDA. Use CPU index as primary on Linux.
  if [[ "$(uname -s)" == "Linux" ]]; then
    uv pip install --quiet --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple "huggingface_hub>=0.20.0" torch "vllm>=0.16.0"
  else
    uv pip install --quiet "huggingface_hub>=0.20.0" torch "vllm>=0.16.0"
  fi
  echo "[bootstrap] Venv ready (huggingface_hub, torch CPU, vllm)"
fi

# Persist install mode for start-vllm (optional: could warn if GPU requested but CPU-only install)
mkdir -p "$ROOT/.codex"
echo "${USE_GPU:-0}" > "$ROOT/.codex/install_mode"

# 3. Model (default: GGUF quantized for CPU; set HF_MODEL_REPO_ID or pass preset: 1|nanbeige, 2|gguf, or any HF repo_id)
HF_MODEL_REPO_ID="${HF_MODEL_REPO_ID:-Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF}"
case "${1:-}" in
  1|nanbeige)   HF_MODEL_REPO_ID="Nanbeige/Nanbeige4.1-3B" ;;
  2|gguf)       HF_MODEL_REPO_ID="Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF" ;;
  gpu|gpu-only) ;;  # already used for USE_GPU
  *)            [[ -n "${1:-}" ]] && HF_MODEL_REPO_ID="$1" ;;
esac
MODEL_NAME="${HF_MODEL_REPO_ID##*/}"
MODEL_DIR="$ROOT/models/$MODEL_NAME"
if [[ ! -d "$MODEL_DIR" ]] || [[ -z "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]]; then
  echo "[bootstrap] Downloading $HF_MODEL_REPO_ID ..."
  # Avoid SOCKS proxy so huggingface_hub uses HTTP proxy only (no socksio dependency)
  unset ALL_PROXY all_proxy 2>/dev/null || true
  "$ROOT/.venv/bin/python" scripts/download_model.py "$ROOT" "$HF_MODEL_REPO_ID"
else
  echo "[bootstrap] Model already present at $MODEL_DIR"
fi

# 4. Codex config and model info for start-vllm
mkdir -p "$ROOT/.codex"
[[ -f "$ROOT/scripts/codex-config.toml.template" ]] || { echo "[bootstrap] ERROR: scripts/codex-config.toml.template not found." >&2; exit 1; }
PORT="${VLLM_PORT:-28080}"
sed -e "s/__VLLM_PORT__/$PORT/g" -e "s/__MODEL_NAME__/$MODEL_NAME/g" "$ROOT/scripts/codex-config.toml.template" > "$ROOT/.codex/config.toml"
# Quote so paths with spaces work when sourced
echo "MODEL_DIR=\"$MODEL_DIR\"" > "$ROOT/.codex/model_info"
echo "SERVED_MODEL_NAME=\"$MODEL_NAME\"" >> "$ROOT/.codex/model_info"
echo "[bootstrap] .codex/config.toml and .codex/model_info installed (model=$MODEL_NAME, port=$PORT)"

echo "[bootstrap] Done. Next: ./start-vllm.sh (then in another terminal: ./run-codex.sh exec \"Your prompt\")"
