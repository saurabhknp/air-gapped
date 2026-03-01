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

- **Install mode (default: CPU-only):** `./bootstrap.sh` uses CPU-first install (PyTorch from CPU index when possible; vLLM may still pull CUDA wheels due to its pinned deps). **Runtime** is always CPU unless you set `VLLM_DEVICE=cuda`. For a full CUDA stack from the start: `VLLM_USE_GPU=1 ./bootstrap.sh` or `./bootstrap.sh gpu`.
- **Default model:** `Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF` (GGUF Q4_K_M quantized, CPU-friendly).
- **Presets:** `./bootstrap.sh 1` or `nanbeige` → full `Nanbeige/Nanbeige4.1-3B`; `./bootstrap.sh 2` or `gguf` → default GGUF.
- **Custom:** `./bootstrap.sh owner/repo` or `HF_MODEL_REPO_ID=owner/repo ./bootstrap.sh`.

Bootstrap writes:

- `.codex/config.toml` — model name, proxy provider, base URL (port from `VLLM_PORT` or 28080).
- `.codex/model_info` — `MODEL_DIR` and `SERVED_MODEL_NAME` for `start-vllm.sh`.

---

## CPU and GPU

- **CPU (default):** `./start-vllm.sh` defaults to `VLLM_DEVICE=cpu` for air-gapped / CPU-only servers. It auto-detects the number of logical CPUs and total RAM, and sets `OMP_NUM_THREADS` and `VLLM_CPU_KVCACHE_SPACE` (~50% of RAM, min 2 GiB) so no manual tuning is required. Context length default is 4096 for CPU.
- **GPU:** set `VLLM_DEVICE=cuda ./start-vllm.sh` to use CUDA. Context length is capped (e.g. 32768); override with `VLLM_MAX_MODEL_LEN`.

### Controlling CPU inference (threads and memory)

When running with `VLLM_DEVICE=cpu` (the default), thread count and KV cache size are **auto-detected** from the machine. You can override them:

| Env | Effect |
|-----|--------|
| **VLLM_CPU_NUM_THREADS** | Number of CPU threads (exported as `OMP_NUM_THREADS`). Unset = auto-detect (all logical CPUs). Override e.g. `VLLM_CPU_NUM_THREADS=4` to limit. |
| **VLLM_CPU_KVCACHE_SPACE** | KV cache size in **GiB**. Unset = auto-detect (~50% of total RAM, minimum 2 GiB). Override e.g. `VLLM_CPU_KVCACHE_SPACE=4` on shared hosts. |

Example:

```bash
VLLM_DEVICE=cpu VLLM_CPU_NUM_THREADS=8 VLLM_CPU_KVCACHE_SPACE=4 ./start-vllm.sh
```

The script forwards these only when `VLLM_DEVICE=cpu`. No code changes are required; env vars are enough for stable, automated CPU runs.

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
