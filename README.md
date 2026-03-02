# Air-Gapped Codex + llama.cpp

**\[ [中文说明](README.zh-CN.md) ]**

---

> **Your ops agent. Offline. One folder.**  
> *Bring a portable AI into the secure room—no cloud, no internet, no compromise.*

---

## Why this exists

Air-gapped ops: no internet, no devices, no docs, no AI. Long K8s commands and configs—memorize or print cheat sheets. Slow and error-prone. **Copy one folder in**; run a Codex-level agent offline. Say "show me unhealthy Pods in namespace X"—it generates the command, runs it, suggests next steps. No internet, no cloud. **In a no-network environment, it's your offline ops expert.**

---

## What it is (technically)

**Air-Gapped Codex + llama.cpp** is a **single, portable directory** that:

- Runs a **local LLM** via [llama.cpp](https://github.com/ggml-org/llama.cpp) (CPU-only inference, no GPU).
- Exposes an **OpenAI-compatible HTTP API** so **[Codex CLI](https://developers.openai.com/codex)** (OpenAI's coding/ops agent) talks to that local model—same agent experience, **fully offline**.
- Can be **prepared once** on a connected machine (download llama.cpp binary and GGUF model, generate config), then **copied as a whole** onto approved media and into the secure area. No internet required on the other side.

Use it for **deployment, configuration, runbooks, and troubleshooting**—without leaving the room or touching the cloud.

---

## Quick start (3 steps)

Use a terminal in this project folder.

### 1. One-time setup (on a machine with internet)

```bash
./bootstrap.sh
```

This downloads the llama.cpp prebuilt binary (Linux x64 CPU), builds **codex-proxy**, downloads the default model ([Nanbeige/Nanbeige4.1-3B](https://huggingface.co/Nanbeige/Nanbeige4.1-3B)), and writes Codex config (pointing at the proxy). When it finishes: `[bootstrap] Done. Next: ...`

### 2. Start the model server and proxy

**Leave this terminal open.**

```bash
./start-llama-server.sh
```

This starts **llama-server** (port 28080) and **codex-proxy** (port 28081). Codex is configured to use the proxy so tools work correctly (avoids the "tool type must be 'function'" error). Wait until the server is up (e.g. open http://127.0.0.1:28080 for the Web UI). First start may take a short while to load the model.

### 3. Run Codex (in a second terminal)

```bash
./run-codex.sh exec "Help me write a Kubernetes Deployment YAML for a simple web app"
```

Codex uses the local model. Replace the quoted text with your real task—configs, scripts, debugging, whatever you need.

**Stop the server when done:** in the server terminal press **Ctrl+C**, or run `./stop-llama-server.sh` from any terminal.

---

## Copying into an air-gapped workspace

1. On a machine **with internet**: run `./bootstrap.sh` and wait for it to finish.  
2. Copy the **entire** project folder (including `models/`, `.venv/`, `.codex/`, `llama_bin/`) onto approved media.  
3. On the workspace machine (no network): run `./start-llama-server.sh`, then in another terminal `./run-codex.sh exec "your task"` as above.

No cloud. No API keys. No internet.

---

## What you need

| Requirement | Notes |
|-------------|--------|
| **uv** | [Install uv](https://docs.astral.sh/uv/getting-started/installation/) (Python/env manager). Check: `uv --version`. |
| **Codex CLI** | In **Cursor**: Preferences → Advanced → **Install CLI**. Or install via npm. Check: `codex --version`. |
| **curl** | For bootstrap: download llama.cpp binary. No build tools or GPU required. |

---

## Commands at a glance

| Command | Purpose |
|--------|--------|
| `./bootstrap.sh` | First-time setup (run once, needs internet). |
| `./start-llama-server.sh` | Start the local model server (keep terminal open). |
| `./run-codex.sh exec "task"` | Run Codex with your task; uses the local server. |
| `./stop-llama-server.sh` | Stop the model server. |
| `./test-api.sh` | Quick check that the server is responding. |

Always run `./run-codex.sh` from **this project folder** so Codex uses this project's config and state (no mixing with `~/.codex`).

---

## Usage guide

### How to use (daily workflow)

**CPU path (llama.cpp, default):**

1. **First time only:** `./bootstrap.sh` (needs internet).
2. **Start backend + proxy:** `./start-llama-server.sh` (leave terminal open).
3. **In another terminal:** `./run-codex.sh exec "your task"`.
4. **When done:** `./stop-llama-server.sh` or Ctrl+C in the server terminal.

**GPU path (vLLM, optional):**

1. **First time only:** `USE_VLLM=1 ./bootstrap.sh` (needs internet + GPU/CUDA).
2. **Start backend + proxy:** `./start-vllm.sh` (leave terminal open).
3. **In another terminal:** `./run-codex.sh exec "your task"`.
4. **When done:** `./stop-vllm.sh` or Ctrl+C in the server terminal.

If vLLM hits **CUDA out of memory**, lower context or VRAM: `VLLM_EXTRA_ARGS="--max-model-len 32768 --gpu-memory-utilization 0.85" ./start-vllm.sh`

**Same from then on:** Codex talks to the proxy (port 28081); the proxy talks to whichever backend you started (llama or vLLM). You only choose CPU vs GPU when you run `start-llama-server.sh` or `start-vllm.sh`.

---

### How to switch models

**CPU (llama.cpp) — GGUF models:**

- Default: [Nanbeige/Nanbeige4.1-3B](https://huggingface.co/Nanbeige/Nanbeige4.1-3B).
- To use another Hugging Face repo (GGUF or compatible), re-run bootstrap with the repo id; this downloads the new model and updates `.codex/config.toml` and `.codex/model_info`:

  ```bash
  HF_MODEL_REPO_ID=owner/repo-name ./bootstrap.sh
  ```

- Then start the server as usual: `./start-llama-server.sh`. The new model is loaded from `models/<repo-name>/`.

**GPU (vLLM) — Hugging Face models:**

- Default vLLM model (when you used `USE_VLLM=1`): [Nanbeige/Nanbeige4.1-3B](https://huggingface.co/Nanbeige/Nanbeige4.1-3B). Started with max 1 concurrent, 100k context, high VRAM use (0.95).
- To use another Hugging Face model, re-run bootstrap with vLLM and set `VLLM_MODEL`:

  ```bash
  VLLM_MODEL=owner/repo-name USE_VLLM=1 ./bootstrap.sh
  ```

- Then start vLLM: `./start-vllm.sh`. vLLM will use the model specified in `.codex/model_info` (`VLLM_MODEL`).

**Note:** CPU uses GGUF repos; GPU (vLLM) uses Hugging Face model ids. They are independent. You can have one GGUF model for CPU and one HF model for GPU.

---

### How to switch between GPU and CPU

You can use **either** llama.cpp (CPU) **or** vLLM (GPU) on the same project; only one backend should run at a time (same port 28080).

**From GPU (vLLM) to CPU (llama.cpp):**

1. Stop the GPU backend: `./stop-vllm.sh`.
2. Ensure you have already run a **CPU** bootstrap at least once (so `models/` has a GGUF and `.codex/model_info` has `MODEL_DIR` / `LLAMA_SERVER`). If you only ever ran `USE_VLLM=1 ./bootstrap.sh`, run a normal bootstrap once: `./bootstrap.sh` (this adds/keeps llama.cpp binary and default GGUF model).
3. Start the CPU backend: `./start-llama-server.sh`.
4. Run Codex as usual: `./run-codex.sh exec "..."`.

If Codex still sends the wrong model name (e.g. the vLLM model name), restore the config for the CPU model by re-running bootstrap without vLLM: `./bootstrap.sh`. That rewrites `.codex/config.toml` with the GGUF model name.

**From CPU (llama.cpp) to GPU (vLLM):**

1. Stop the CPU backend: `./stop-llama-server.sh`.
2. Ensure vLLM is installed and a vLLM model is set. If you have not yet run bootstrap with vLLM, run: `USE_VLLM=1 ./bootstrap.sh` (or `VLLM_MODEL=owner/repo USE_VLLM=1 ./bootstrap.sh`).
3. Start the GPU backend: `./start-vllm.sh`. This will update `.codex/config.toml` to the vLLM model name so requests match.
4. Run Codex as usual: `./run-codex.sh exec "..."`.

**Summary:**

| You want to use | Do this |
|-----------------|--------|
| CPU (llama.cpp) | `./stop-vllm.sh` (if vLLM was running), then `./start-llama-server.sh`. Optionally `./bootstrap.sh` to refresh config model name. |
| GPU (vLLM)      | `./stop-llama-server.sh` (if llama was running), then `./start-vllm.sh`. |

---

### Port and tuning (optional)

**Port:** Backend default is 28080, proxy is 28081. Override with `LLAMA_PORT=28081 ./start-llama-server.sh` (or `VLLM_PORT=28081 ./start-vllm.sh`) and use the same port when running Codex if you change it.

**CPU context / threads:** `LLAMA_CTX_SIZE=8192` and/or `LLAMA_THREADS=8` when starting: `LLAMA_CTX_SIZE=8192 LLAMA_THREADS=8 ./start-llama-server.sh`.

---

## Troubleshooting

| Issue | What to do |
|------|------------|
| `.codex/config.toml not found` | Run `./bootstrap.sh` first. |
| "Model server is not reachable" or Codex doesn't answer | Start the server: `./start-llama-server.sh`, wait until it's up, then run `./run-codex.sh exec "..."`. |
| Codex CLI not found | Install from Cursor (Preferences → Advanced → Install CLI) or npm; open a new terminal. |
| Port 28080 in use | Run `./stop-llama-server.sh`, wait a few seconds, try again. Or use another port: `LLAMA_PORT=28081 ./start-llama-server.sh` and `LLAMA_PORT=28081 ./run-codex.sh exec "..."`. |
| 400 `'type' of tool must be 'function'` | Codex sends tools llama-server rejects. `./run-codex.sh` uses profile `local` (web_search=disabled). If it still happens, start with `USE_CODEX_PROXY=1 ./start-llama-server.sh` and point config at the proxy (see docs). |
| llama-server not found | Run `./bootstrap.sh` to download the prebuilt binary. |

---

## Project charter and docs

- **[CHARTER.md](CHARTER.md)** — Why this project exists, who it's for, and what we will (and won't) do.
- **[CHANGELOG.md](CHANGELOG.md)** — Release history. Current version: **0.4.0** (see [VERSION](VERSION)).
- **[docs/README.md](docs/README.md)** — Technical reference (architecture, bootstrap, config).
- **[README.zh-CN.md](README.zh-CN.md)** — 中文说明。

---

## Layout (reference)

| Path | Purpose |
|------|--------|
| `bootstrap.sh` | One-time setup (run once). |
| `start-llama-server.sh` | Start llama.cpp (CPU) + proxy. |
| `stop-llama-server.sh` | Stop llama-server and proxy. |
| `start-vllm.sh` | Start vLLM (GPU) + proxy (requires `USE_VLLM=1` at bootstrap). |
| `stop-vllm.sh` | Stop vLLM and proxy. |
| `run-codex.sh` | Run Codex with this project's config. |
| `test-api.sh` | Test server response. |
| `models/`, `.venv/`, `.codex/`, `llama_bin/` | Created by bootstrap; copy them when moving the kit. |

**Make:** `make deps` (= bootstrap), `make clean` (remove generated content), `make test` (run checks; requires `codex` on PATH). For GPU: `USE_VLLM=1 ./bootstrap.sh` then `./start-vllm.sh`.

---

## License

MIT. See [LICENSE](LICENSE).
