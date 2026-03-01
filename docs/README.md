# Technical documentation

This folder holds technical reference for the **Air-Gapped Codex + llama.cpp** project. For getting started and the project's purpose, see the [main README](../README.md) and [CHARTER](../CHARTER.md).

---

## Architecture overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Operator (in air-gapped workspace)                              │
│  runs: ./run-codex.sh exec "deploy K8s app..."                   │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Codex CLI  (CODEX_HOME = project/.codex)                        │
│  - Reads .codex/config.toml (model, provider = proxy, base_url)  │
│  - Sends requests to base_url (Responses API: /v1/responses)     │
└─────────────────────────────┬────────────────────────────────────┘
                              │  HTTP (127.0.0.1:28080)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  llama-server  (./start-llama-server.sh)                         │
│  - llama.cpp HTTP server, CPU-only                               │
│  - OpenAI-compatible API: /v1/models, /v1/chat/completions, etc.│
│  - Model: GGUF file from .codex/model_info (set by bootstrap)    │
└─────────────────────────────────────────────────────────────────┘
```

- **Bootstrap** (once, on a machine with internet): download prebuilt llama.cpp binary (default: Linux x64 CPU from [releases](https://github.com/ggml-org/llama.cpp/releases)), create `.venv` with huggingface_hub, download GGUF model into `models/<name>`, generate `.codex/config.toml` and `.codex/model_info` (including path to `llama-server`).
- **Portable copy**: the whole directory (including `models/`, `.venv/`, `.codex/`, `llama_bin/`) is self-contained. No network needed at runtime.
- **Codex** uses `CODEX_HOME` pointing to the project's `.codex`, so config and state stay inside the project.

---

## Bootstrap and model choice

- **Default model:** [Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF](https://huggingface.co/Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF) (GGUF Q4_K_M, ~2GB). Set `HF_MODEL_REPO_ID=owner/repo ./bootstrap.sh` to use another GGUF repo.
- **Binary:** Bootstrap downloads the latest prebuilt tarball (e.g. `llama-<tag>-bin-ubuntu-x64.tar.gz`) into `llama_bin/`. Use `LLAMA_BIN_OS_ARCH=macos-arm64` or `macos-x64` on macOS.

Bootstrap writes:

- `.codex/config.toml` — model name, proxy provider, base URL (port from `LLAMA_PORT` or 28080).
- `.codex/model_info` — `MODEL_DIR`, `SERVED_MODEL_NAME`, `LLAMA_SERVER` (path to downloaded `llama-server` binary) for `start-llama-server.sh`.

---

## Server and runtime

- **CPU only:** No GPU; inference runs on CPU. Thread count is auto-detected (or set `LLAMA_THREADS`). Context size default is 4096 (`LLAMA_CTX_SIZE`).
- **Port / context / threads:** `LLAMA_PORT`, `LLAMA_CTX_SIZE`, `LLAMA_THREADS` when starting the server (see `start-llama-server.sh`).

---

## Config and state

- **Codex:** All config and state under `CODEX_HOME` (project's `.codex`). See [Advanced Config](https://developers.openai.com/codex/config-advanced).
- **llama-server:** Port via `LLAMA_PORT`; binary path in `.codex/model_info` as `LLAMA_SERVER`.

---

## References

- **llama.cpp:** [GitHub](https://github.com/ggml-org/llama.cpp), [server README](https://github.com/ggml-org/llama.cpp/tree/master/tools/server).
- **Codex:** [overview](https://developers.openai.com/codex), [CLI reference](https://developers.openai.com/codex/cli/reference), [config advanced](https://developers.openai.com/codex/config-advanced).

---

*This technical doc is intended for maintainers and operators who need to understand or extend the stack. For day-to-day use, the main [README](../README.md) and [CHARTER](../CHARTER.md) are the entry points.*
