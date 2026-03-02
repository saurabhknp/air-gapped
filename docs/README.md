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
│  - Profile "local": web_search=disabled (llama-server accepts    │
│    only type "function" tools)                                   │
│  - Sends requests to base_url (Responses API: /v1/responses)    │
└─────────────────────────────┬────────────────────────────────────┘
                              │  HTTP (127.0.0.1:28080)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  llama-server  (./start-llama-server.sh)                         │
│  - llama.cpp HTTP server, CPU-only; has /v1/responses natively   │
│  - /v1/models, /v1/chat/completions, /v1/responses               │
│  - Model: GGUF file from .codex/model_info (set by bootstrap)    │
└─────────────────────────────────────────────────────────────────┘
```

**Optional:** If you still see 400 `'type' of tool must be 'function'` (e.g. from other tools Codex sends), start with `USE_CODEX_PROXY=1 ./start-llama-server.sh` and point config at the proxy (see README).

- **Bootstrap** (once, on a machine with internet): download prebuilt llama.cpp binary (default: Linux x64 CPU from [releases](https://github.com/ggml-org/llama.cpp/releases)), create `.venv` with huggingface_hub, download GGUF model into `models/<name>`, generate `.codex/config.toml` and `.codex/model_info` (including path to `llama-server`).
- **Portable copy**: the whole directory (including `models/`, `.venv/`, `.codex/`, `llama_bin/`) is self-contained. No network needed at runtime.
- **Codex** uses `CODEX_HOME` pointing to the project's `.codex`, so config and state stay inside the project.

---

## Bootstrap and model choice

- **Default model:** [Nanbeige/Nanbeige4.1-3B](https://huggingface.co/Nanbeige/Nanbeige4.1-3B). Set `HF_MODEL_REPO_ID=owner/repo ./bootstrap.sh` to use another repo.
- **Binary:** Bootstrap downloads the latest prebuilt tarball (e.g. `llama-<tag>-bin-ubuntu-x64.tar.gz`) into `llama_bin/`. Use `LLAMA_BIN_OS_ARCH=macos-arm64` or `macos-x64` on macOS.

Bootstrap writes:

- `.codex/config.toml` — model, provider `local`, base URL pointing at codex-proxy (port from `CODEX_PROXY_PORT` or 28081) so Codex gets correct tool handling, profile `local` with `web_search=disabled`.
- `.codex/model_info` — `MODEL_DIR`, `SERVED_MODEL_NAME`, `LLAMA_SERVER` for CPU; when `USE_VLLM=1`, also `VLLM_MODEL`, `VLLM_SERVED_NAME`.

---

## Usage, model switch, and CPU/GPU switch

**Daily use:** Start one backend (CPU or GPU), then run Codex. Codex always talks to the proxy (28081); the proxy forwards to the backend (28080).

| Backend | Bootstrap (once) | Start | Stop |
|---------|------------------|--------|------|
| CPU (llama.cpp) | `./bootstrap.sh` | `./start-llama-server.sh` | `./stop-llama-server.sh` |
| GPU (vLLM) | `USE_VLLM=1 ./bootstrap.sh` | `./start-vllm.sh` | `./stop-vllm.sh` |

**Switch model (CPU):** Re-bootstrap with a different GGUF repo: `HF_MODEL_REPO_ID=owner/repo ./bootstrap.sh`. Then `./start-llama-server.sh`.

**Switch model (GPU):** Re-bootstrap with vLLM and a different HF model: `VLLM_MODEL=owner/repo USE_VLLM=1 ./bootstrap.sh`. Then `./start-vllm.sh`.

**Switch CPU ↔ GPU:** Only one backend runs at a time (same port 28080). To use CPU: stop vLLM (`./stop-vllm.sh`), then `./start-llama-server.sh`. To use GPU: stop llama (`./stop-llama-server.sh`), then `./start-vllm.sh`. If you had been on vLLM and switch to CPU, re-run `./bootstrap.sh` (no `USE_VLLM`) to restore the GGUF model name in `.codex/config.toml` if Codex requests fail. If you had been on CPU and switch to vLLM, `./start-vllm.sh` updates config to the vLLM model name automatically.

---

## Server and runtime

- **CPU (default):** llama.cpp; no GPU. Thread count auto-detected (or set `LLAMA_THREADS`). Context size default 8192 (`LLAMA_CTX_SIZE`). Start with `./start-llama-server.sh`.
- **GPU (optional):** vLLM for faster inference. Default model: Nanbeige/Nanbeige4.1-3B. Bootstrap with `USE_VLLM=1 ./bootstrap.sh`. Start with `./start-vllm.sh` (defaults: 1 concurrent, 100k context, gpu_memory_utilization=0.95). Stop with `./stop-vllm.sh`. Same port layout (backend 28080, proxy 28081). On smaller GPUs or OOM, set `VLLM_EXTRA_ARGS="--max-model-len 32768 --gpu-memory-utilization 0.85"`.
- **Port / context / threads:** `LLAMA_PORT` (or `VLLM_PORT` for vLLM), `LLAMA_CTX_SIZE`, `LLAMA_THREADS` when starting the server (see `start-llama-server.sh`).

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
