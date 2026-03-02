#!/usr/bin/env bash
# One-time setup: download llama.cpp binary (CPU x64), download GGUF model, write Codex config.
# Run on a machine with internet. No GPU; inference is CPU-only via llama.cpp.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "[bootstrap] ROOT=$ROOT"

# 1. Dirs
mkdir -p "$ROOT/models"
echo "[bootstrap] Created models/"

# 2. Minimal venv for model download only (huggingface_hub)
if [[ ! -d "$ROOT/.venv" ]]; then
  uv venv "$ROOT/.venv" --python 3.12
  echo "[bootstrap] Created .venv"
fi
export VIRTUAL_ENV="$ROOT/.venv"
export PATH="$ROOT/.venv/bin:$PATH"
uv pip install --quiet "huggingface_hub>=0.20.0"
echo "[bootstrap] Venv ready (huggingface_hub for download only)"

# 3. Download llama.cpp prebuilt binary (default: Linux x64 CPU)
#    Override: LLAMA_BIN_OS_ARCH=macos-arm64 or linux-x64 (default)
LLAMA_SERVER=""
if [[ -d "$ROOT/llama_bin" ]]; then
  LLAMA_SERVER=$(find "$ROOT/llama_bin" -maxdepth 3 -name "llama-server" -type f -executable -print -quit 2>/dev/null)
fi
if [[ -z "$LLAMA_SERVER" ]] || [[ ! -x "$LLAMA_SERVER" ]]; then
  echo "[bootstrap] Downloading llama.cpp binary (CPU x64) ..."
  LLAMA_SERVER=$("$ROOT/scripts/download_llama_bin.sh")
fi
if [[ -z "$LLAMA_SERVER" ]] || [[ ! -x "$LLAMA_SERVER" ]]; then
  echo "[bootstrap] ERROR: llama-server not found after download." >&2
  exit 1
fi
echo "[bootstrap] Using llama-server at $LLAMA_SERVER"

# 4. Model for CPU/llama.cpp: must be a GGUF repo. Default: Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF
HF_MODEL_REPO_ID="${HF_MODEL_REPO_ID:-Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF}"
MODEL_NAME="${HF_MODEL_REPO_ID##*/}"
MODEL_DIR="$ROOT/models/$MODEL_NAME"
if [[ ! -d "$MODEL_DIR" ]] || [[ -z "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]]; then
  echo "[bootstrap] Downloading $HF_MODEL_REPO_ID ..."
  unset ALL_PROXY all_proxy 2>/dev/null || true
  "$ROOT/.venv/bin/python" scripts/download_model.py "$ROOT" "$HF_MODEL_REPO_ID"
else
  echo "[bootstrap] Model already present at $MODEL_DIR"
fi

# 5. Codex config and model info (base_url = codex-proxy so Codex gets correct tool handling)
mkdir -p "$ROOT/.codex"
[[ -f "$ROOT/scripts/codex-config.toml.template" ]] || { echo "[bootstrap] ERROR: scripts/codex-config.toml.template not found." >&2; exit 1; }
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
sed -e "s/__PROXY_PORT__/$PROXY_PORT/g" -e "s/__MODEL_NAME__/$MODEL_NAME/g" "$ROOT/scripts/codex-config.toml.template" > "$ROOT/.codex/config.toml"
echo "MODEL_DIR=\"$MODEL_DIR\"" > "$ROOT/.codex/model_info"
echo "SERVED_MODEL_NAME=\"$MODEL_NAME\"" >> "$ROOT/.codex/model_info"
echo "LLAMA_SERVER=\"$LLAMA_SERVER\"" >> "$ROOT/.codex/model_info"

# Optional: vLLM (GPU) support. When USE_VLLM=1, install vllm and set VLLM_MODEL for start-vllm.sh
if [[ "${USE_VLLM:-0}" == "1" ]]; then
  echo "[bootstrap] Installing vLLM (GPU) ..."
  uv pip install --quiet "vllm>=0.6.0"
  VLLM_MODEL="${VLLM_MODEL:-$HF_MODEL_REPO_ID}"
  VLLM_SERVED_NAME="${VLLM_MODEL##*/}"
  # GGUF models need a tokenizer from the base model; download it if not present
  VLLM_TOKENIZER=""
  if [[ "$VLLM_MODEL" == *GGUF* || "$VLLM_MODEL" == *gguf* ]]; then
    BASE_MODEL="${VLLM_BASE_MODEL:-Nanbeige/Nanbeige4.1-3B}"
    BASE_MODEL_NAME="${BASE_MODEL##*/}"
    BASE_MODEL_DIR="$ROOT/models/$BASE_MODEL_NAME"
    if [[ ! -d "$BASE_MODEL_DIR" ]] || [[ ! -f "$BASE_MODEL_DIR/tokenizer.json" ]]; then
      echo "[bootstrap] Downloading tokenizer from $BASE_MODEL for GGUF model ..."
      "$ROOT/.venv/bin/python" -c "
from huggingface_hub import snapshot_download
snapshot_download('$BASE_MODEL', local_dir='$BASE_MODEL_DIR',
    allow_patterns=['tokenizer*', 'special_tokens*', 'added_tokens*', 'config.json', 'generation_config.json'])
"
    fi
    VLLM_TOKENIZER="$BASE_MODEL_DIR"
  fi
  echo "VLLM_MODEL=\"$VLLM_MODEL\"" >> "$ROOT/.codex/model_info"
  echo "VLLM_SERVED_NAME=\"$VLLM_SERVED_NAME\"" >> "$ROOT/.codex/model_info"
  [[ -n "$VLLM_TOKENIZER" ]] && echo "VLLM_TOKENIZER=\"$VLLM_TOKENIZER\"" >> "$ROOT/.codex/model_info"
  echo "[bootstrap] vLLM ready. Model: $VLLM_MODEL. Start with: ./start-vllm.sh"
fi

echo "[bootstrap] .codex/config.toml and .codex/model_info installed (model=$MODEL_NAME, proxy_port=$PROXY_PORT)"

echo "[bootstrap] Done. Next: ./start-llama-server.sh (CPU) or ./start-vllm.sh (GPU, requires USE_VLLM=1 at bootstrap)"
