#!/usr/bin/env python3
"""Download a Hugging Face model to project models/ directory.

Usage:
  python scripts/download_model.py <ROOT> [REPO_ID]

  REPO_ID: Hugging Face repo (e.g. Nanbeige/Nanbeige4.1-3B). Omit to use default.
  Default: Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF (GGUF quantized, CPU-friendly).
  Presets: "1" or "nanbeige" -> Nanbeige/Nanbeige4.1-3B (full); "2" or "gguf" -> default GGUF.

  Use project .venv: .venv/bin/python scripts/download_model.py <ROOT> [REPO_ID]

  For gated repos set HF_TOKEN or run: huggingface-cli login
"""
from __future__ import annotations

import os
import sys

DEFAULT_REPO = "Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF"
PRESETS: dict[str, str] = {
    "1": "Nanbeige/Nanbeige4.1-3B",
    "nanbeige": "Nanbeige/Nanbeige4.1-3B",
    "2": DEFAULT_REPO,
    "gguf": DEFAULT_REPO,
}


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: download_model.py <ROOT> [REPO_ID]", file=sys.stderr)
        print("  REPO_ID: HF repo (e.g. owner/repo). Default:", DEFAULT_REPO, file=sys.stderr)
        print("  Presets: 1|nanbeige, 2|gguf", file=sys.stderr)
        sys.exit(1)
    root = os.path.abspath(sys.argv[1])
    raw = (sys.argv[2].strip() if len(sys.argv) > 2 else "").lower()
    repo_id = PRESETS.get(raw, sys.argv[2] if len(sys.argv) > 2 else DEFAULT_REPO)
    if not repo_id or "/" not in repo_id:
        repo_id = DEFAULT_REPO
    local_name = repo_id.split("/")[-1]
    local_dir = os.path.join(root, "models", local_name)
    os.makedirs(local_dir, exist_ok=True)
    from huggingface_hub import snapshot_download
    snapshot_download(
        repo_id=repo_id,
        local_dir=local_dir,
        local_dir_use_symlinks=False,
    )
    print(f"Model saved to {local_dir}")
    print(f"Served model name (for config): {local_name}")


if __name__ == "__main__":
    main()
