#!/usr/bin/env bash
# Download prebuilt llama.cpp binaries (default: Linux x64 CPU). Prints path to llama-server to stdout.
# Usage: LLAMA_BIN_DIR=$(./scripts/download_llama_bin.sh)  # then use $LLAMA_BIN_DIR/llama-server
# Or: scripts/download_llama_bin.sh  # prints path to llama-server binary
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${LLAMA_BIN_DIR:-$ROOT/llama_bin}"
# Default: Linux x64 CPU. Override: LLAMA_BIN_OS_ARCH=macos-arm64 | macos-x64 | linux-x64
OS_ARCH="${LLAMA_BIN_OS_ARCH:-linux-x64}"

download_and_extract() {
  local tag="$1"
  local asset_name="$2"
  local url="https://github.com/ggml-org/llama.cpp/releases/download/${tag}/${asset_name}"
  mkdir -p "$OUT_DIR"
  local tmp_tar="$OUT_DIR/.dl.tar.gz"
  echo "[download_llama_bin] Fetching $asset_name ..." >&2
  curl -sSLf -H "User-Agent: air-gapped-codex/1.0" -o "$tmp_tar" "$url"
  tar -xzf "$tmp_tar" -C "$OUT_DIR"
  rm -f "$tmp_tar"
  local server_bin
  server_bin=$(find "$OUT_DIR" -maxdepth 2 -name "llama-server" -type f -print -quit)
  if [[ -z "$server_bin" ]]; then
    server_bin=$(find "$OUT_DIR" -name "llama-server" -type f -print -quit)
  fi
  if [[ -z "$server_bin" ]] || [[ ! -x "$server_bin" ]]; then
    echo "[download_llama_bin] ERROR: llama-server not found in $OUT_DIR" >&2
    return 1
  fi
  echo "$server_bin"
}

# Check if we already have a usable binary
existing=""
if [[ -d "$OUT_DIR" ]]; then
  existing=$(find "$OUT_DIR" -maxdepth 3 -name "llama-server" -type f -executable -print -quit 2>/dev/null || true)
fi
if [[ -n "$existing" ]]; then
  echo "$existing"
  exit 0
fi

# Fetch latest release tag (portable: no python required)
meta=$(curl -sSLf -H "Accept: application/vnd.github+json" -H "User-Agent: air-gapped-codex/1.0" "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest")
tag=$(echo "$meta" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"[[:space:]]*$/\1/')
if [[ -z "$tag" ]]; then
  echo "[download_llama_bin] ERROR: could not get latest release tag (check network)" >&2
  exit 1
fi

# Asset name: llama-<tag>-bin-ubuntu-x64.tar.gz (tag is e.g. b8183)
asset_name="llama-${tag}-bin-ubuntu-x64.tar.gz"
case "$OS_ARCH" in
  macos-x64)   asset_name="llama-${tag}-bin-macos-x64.tar.gz" ;;
  macos-arm64) asset_name="llama-${tag}-bin-macos-arm64.tar.gz" ;;
  linux-x64)   asset_name="llama-${tag}-bin-ubuntu-x64.tar.gz" ;;
  *)           asset_name="llama-${tag}-bin-ubuntu-x64.tar.gz" ;;
esac

download_and_extract "$tag" "$asset_name"
