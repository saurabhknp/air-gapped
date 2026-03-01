# Technical documentation

This folder holds technical reference for the **Air-Gapped Codex + vLLM** project. For getting started and the project’s purpose, see the [main README](../README.md) and [CHARTER](../CHARTER.md).

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
│  vLLM  (./start-vllm.sh)                                         │
│  - Serves local model (GPU or CPU)                               │
│  - Exposes OpenAI-compatible API including /v1/responses          │
│  - Model and config from .codex/model_info (set by bootstrap)   │
└─────────────────────────────────────────────────────────────────┘
```

- **Bootstrap** (once, on a machine with internet): create `.venv`, install vLLM and deps, download model into `models/<name>`, generate `.codex/config.toml` and `.codex/model_info`.
- **Portable copy**: the whole directory (including `models/`, `.venv/`, `.codex/`) is self-contained. No network needed at runtime.
- **Codex** uses `CODEX_HOME` pointing to the project’s `.codex`, so config and state stay inside the project and do not touch `~/.codex`.

---

## Why vLLM ≥ 0.16 and Responses API

Codex CLI can talk to a backend via the **Responses API** (`/v1/responses`). When `wire_api = "responses"` in `.codex/config.toml`, Codex sends requests to that endpoint. **vLLM 0.16+** implements this API; older vLLM versions only had `/v1/chat/completions` and would return 404 for Codex. So we pin to **vLLM ≥ 0.16** and document it in [VERSIONS.md](../VERSIONS.md).

---

## Bootstrap and model choice

- **Default model:** `Nanbeige/Nanbeige4.1-3B` (good balance of size and quality for ops tasks).
- **Presets:** `./bootstrap.sh 2` or `./bootstrap.sh gguf` → GGUF quantized model (smaller, CPU-friendly).
- **Custom:** `./bootstrap.sh owner/repo` or `HF_MODEL_REPO_ID=owner/repo ./bootstrap.sh`.

Bootstrap writes:

- `.codex/config.toml` — model name, proxy provider, base URL (port from `VLLM_PORT` or 28080).
- `.codex/model_info` — `MODEL_DIR` and `SERVED_MODEL_NAME` for `start-vllm.sh`.

---

## CPU and GPU

- **GPU (default):** `./start-vllm.sh` uses CUDA if available. Context length is capped (e.g. 32768) so the model fits in GPU memory; override with `VLLM_MAX_MODEL_LEN`.
- **CPU:** `VLLM_DEVICE=cpu ./start-vllm.sh`. Uses a smaller default context (4096). Slower but allows use on machines without GPUs (e.g. many secure workstations).

---

## Config and state

- **Codex:** All config and state under `CODEX_HOME` (project’s `.codex`). See [Advanced Config](https://developers.openai.com/codex/config-advanced). Keys such as `model_context_window` can be set in `.codex/config.toml` to tune behavior and reduce “model metadata not found” warnings.
- **vLLM:** Port via `VLLM_PORT`; device via `VLLM_DEVICE`; context cap via `VLLM_MAX_MODEL_LEN`. See script comments and README.

---

## Version baseline and references

- **[VERSIONS.md](../VERSIONS.md)** — Recorded baseline (vLLM 0.16.x, Codex CLI 0.106.x) and links to official docs.
- **vLLM:** [docs](https://docs.vllm.ai/en/latest/), [installation](https://docs.vllm.ai/en/latest/getting_started/installation.html).
- **Codex:** [overview](https://developers.openai.com/codex), [CLI reference](https://developers.openai.com/codex/cli/reference), [config advanced](https://developers.openai.com/codex/config-advanced).

---

*This technical doc is intended for maintainers and operators who need to understand or extend the stack. For day-to-day use, the main [README](../README.md) and [CHARTER](../CHARTER.md) are the entry points.*
