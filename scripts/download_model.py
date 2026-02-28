#!/usr/bin/env python3
"""Download Nanbeige4.1-3B to a local directory. Run with: python scripts/download_model.py <ROOT> (use project .venv: .venv/bin/python scripts/download_model.py <ROOT>)."""
import os
import sys

def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: download_model.py <ROOT>", file=sys.stderr)
        sys.exit(1)
    root = os.path.abspath(sys.argv[1])
    local_dir = os.path.join(root, "models", "Nanbeige4.1-3B")
    os.makedirs(local_dir, exist_ok=True)
    from huggingface_hub import snapshot_download
    snapshot_download(
        repo_id="Nanbeige/Nanbeige4.1-3B",
        local_dir=local_dir,
        local_dir_use_symlinks=False,
    )
    print(f"Model saved to {local_dir}")

if __name__ == "__main__":
    main()
