# Dependency and version baseline

This file records the **current version baseline** used and tested for this project. Check these when upgrading or debugging.

---

## llama.cpp

| Item | Value |
|------|--------|
| **Source** | https://github.com/ggml-org/llama.cpp |
| **Binary** | Prebuilt from [releases](https://github.com/ggml-org/llama.cpp/releases); default asset: `llama-<tag>-bin-ubuntu-x64.tar.gz` (Linux x64 CPU). Extracted to `llama_bin/`. |
| **Server binary** | `llama_bin/llama-<tag>/llama-server` (path stored in `.codex/model_info` as `LLAMA_SERVER`). |
| **Server docs** | https://github.com/ggml-org/llama.cpp/tree/master/tools/server |

**Why llama.cpp:** Lightweight, C++ inference with OpenAI-compatible HTTP API. We download the CPU x64 Linux binary; no build or GPU required.

---

## Codex CLI

| Item | Value |
|------|--------|
| **Baseline version** | **0.106.0** (as of 2026-02-26; install from Cursor or npm) |
| **Install (Cursor)** | Cursor → Preferences → Advanced → **Install CLI** |
| **Install (npm)** | `npm install -g @openai/codex@0.106.0` |
| **Changelog** | https://developers.openai.com/codex/changelog |
| **Documentation** | https://developers.openai.com/codex |
| **CLI overview** | https://developers.openai.com/codex/cli |
| **CLI reference** | https://developers.openai.com/codex/cli/reference |
| **Config basics** | https://developers.openai.com/codex/config-basic |
| **Advanced config** | https://developers.openai.com/codex/config-advanced |
| **Config reference** | https://developers.openai.com/codex/config-reference |

Codex is **not** a Python dependency of this repo; it is installed separately (Cursor or npm) and must be on `PATH`. This project configures Codex via `CODEX_HOME` and `.codex/config.toml` to point at the local llama-server (OpenAI-compatible API).

---

## Other deps

- **huggingface_hub** ≥ 0.20.0 — used by `scripts/download_model.py` to fetch GGUF models. Installed in project `.venv` (bootstrap).
- **Build tools (bootstrap):** `git`, `cmake`, C++ compiler (e.g. `g++`, `clang`).

---

*Last updated: 2026-03-01 (baseline: llama.cpp from source, CPU-only; Codex CLI 0.106.0).*
