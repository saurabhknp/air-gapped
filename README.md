# Air-Gapped Codex + vLLM

**\[ [中文说明](README.zh-CN.md) ]**

---

> **Your ops agent. Offline. One folder.**  
> *Bring a portable AI into the secure room—no cloud, no internet, no compromise.*

---

## Why this exists

Air-gapped ops: no internet, no devices, no docs, no AI. Long K8s commands and configs—memorize or print cheat sheets. Slow and error-prone. **Copy one folder in**; run a Codex-level agent offline. Say “show me unhealthy Pods in namespace X”—it generates the command, runs it, suggests next steps. No internet, no cloud. **In a no-network environment, it’s your offline ops expert.**

---

## What it is (technically)

**Air-Gapped Codex + vLLM** is a **single, portable directory** that:

- Runs a **local LLM** (via [vLLM](https://docs.vllm.ai/)) on the workspace machine—**GPU or CPU**.
- Drives **[Codex CLI](https://developers.openai.com/codex)** (OpenAI’s coding/ops agent) against that local model, so you get the same agent experience you’d get with a cloud API, but **fully offline**.
- Can be **prepared once** on a connected machine (download model, install deps, generate config), then **copied as a whole** onto approved media and into the secure area. No internet required on the other side.

Use it for **deployment, configuration, runbooks, and troubleshooting**—without leaving the room or touching the cloud.

---

## Quick start (3 steps)

Use a terminal in this project folder.

### 1. One-time setup (on a machine with internet)

```bash
./bootstrap.sh
```

This creates a Python env, downloads the default model (~6GB), and writes config. When it finishes, you’ll see: `[bootstrap] Done. Next: ...`

### 2. Start the model server

**Leave this terminal open.**

```bash
./start-vllm.sh
```

Wait until the server is up (e.g. “Uvicorn running on http://127.0.0.1:28080”). First start can take 1–2 minutes.

### 3. Run Codex (in a second terminal)

```bash
./run-codex.sh exec "Help me write a Kubernetes Deployment YAML for a simple web app"
```

Codex uses the local model. Replace the quoted text with your real task—configs, scripts, debugging, whatever you need.

**Stop the server when done:** in the vLLM terminal press **Ctrl+C**, or run `./stop-vllm.sh` from any terminal.

---

## Copying into an air-gapped workspace

1. On a machine **with internet**: run `./bootstrap.sh` and wait for it to finish.  
2. Copy the **entire** project folder (including `models/`, `.venv/`, `.codex/`) onto approved media.  
3. On the workspace machine (no network): run `./start-vllm.sh`, then in another terminal `./run-codex.sh exec "your task"` as above.

No cloud. No API keys. No internet.

---

## What you need

| Requirement | Notes |
|-------------|--------|
| **uv** | [Install uv](https://docs.astral.sh/uv/getting-started/installation/) (Python/env manager). Check: `uv --version`. |
| **Codex CLI** | In **Cursor**: Preferences → Advanced → **Install CLI**. Or install via npm. Check: `codex --version`. |
| **GPU or CPU** | GPU is faster; **CPU-only is supported** (e.g. `VLLM_DEVICE=cpu ./start-vllm.sh`) for machines without GPUs. |

---

## Commands at a glance

| Command | Purpose |
|--------|---------|
| `./bootstrap.sh` | First-time setup (run once, needs internet). |
| `./start-vllm.sh` | Start the local model server (keep terminal open). |
| `./run-codex.sh exec "task"` | Run Codex with your task; uses the local server. |
| `./stop-vllm.sh` | Stop the model server. |
| `./test-vllm-api.sh` | Quick check that the server is responding. |

Always run `./run-codex.sh` from **this project folder** so Codex uses this project’s config and state (no mixing with `~/.codex`).

---

## Optional: different model or CPU-only

**Another model (e.g. GGUF quantized):**

```bash
./bootstrap.sh 2          # or: ./bootstrap.sh gguf
# then ./start-vllm.sh and ./run-codex.sh as usual
```

**CPU-only (no GPU):**

```bash
VLLM_DEVICE=cpu ./start-vllm.sh
```

Slower, but works on locked-down workstations with no GPU.

---

## Troubleshooting

| Issue | What to do |
|------|------------|
| `.codex/config.toml not found` | Run `./bootstrap.sh` first. |
| “vLLM is not reachable” or Codex doesn’t answer | Start the server: `./start-vllm.sh`, wait until it’s up, then run `./run-codex.sh exec "..."`. |
| Codex CLI not found | Install from Cursor (Preferences → Advanced → Install CLI) or npm; open a new terminal. |
| Port 28080 in use | Run `./stop-vllm.sh`, wait a few seconds, try again. Or use another port: `VLLM_PORT=28081 ./start-vllm.sh` and `VLLM_PORT=28081 ./run-codex.sh exec "..."`. |
| Out of memory (OOM) | Try a smaller context: `VLLM_MAX_MODEL_LEN=8192 ./start-vllm.sh`. |

---

## Project charter and docs

- **[CHARTER.md](CHARTER.md)** — Why this project exists, who it’s for, and what we will (and won’t) do. All development is guided by it.
- **[VERSIONS.md](VERSIONS.md)** — Version baseline (vLLM ≥ 0.16, Codex CLI) and links to official docs.
- **[docs/README.md](docs/README.md)** — Technical reference (architecture, bootstrap, CPU/GPU, config).
- **[README.zh-CN.md](README.zh-CN.md)** — 中文说明。

---

## Layout (reference)

| Path | Purpose |
|------|--------|
| `CHARTER.md` | Project charter (vision, principles, scope). |
| `VERSIONS.md` | Version baseline and doc links. |
| `docs/README.md` | Technical documentation. |
| `bootstrap.sh` | One-time setup (run once). |
| `start-vllm.sh` | Start the model server. |
| `stop-vllm.sh` | Stop the model server. |
| `run-codex.sh` | Run Codex with this project’s config. |
| `test-vllm-api.sh` | Test server response. |
| `models/`, `.venv/`, `.codex/` | Created by bootstrap; copy them when moving the kit. |

**Make:** `make deps` (= bootstrap), `make clean` (remove generated content), `make test` (run checks; requires `codex` on PATH).

---

## License

MIT. See [LICENSE](LICENSE).
