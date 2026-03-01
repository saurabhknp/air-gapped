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
- Can be **prepared once** on a connected machine (build llama.cpp, download GGUF model, generate config), then **copied as a whole** onto approved media and into the secure area. No internet required on the other side.

Use it for **deployment, configuration, runbooks, and troubleshooting**—without leaving the room or touching the cloud.

---

## Quick start (3 steps)

Use a terminal in this project folder.

### 1. One-time setup (on a machine with internet)

```bash
./bootstrap.sh
```

This downloads the llama.cpp prebuilt binary (Linux x64 CPU), downloads the default GGUF model ([Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF](https://huggingface.co/Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF), ~2GB), and writes Codex config. When it finishes: `[bootstrap] Done. Next: ...`

### 2. Start the model server

**Leave this terminal open.**

```bash
./start-llama-server.sh
```

Wait until the server is up (e.g. you can open http://127.0.0.1:28080 in a browser for the Web UI). First start may take a short while to load the model.

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

## Optional: different model or port

**Default model:** [Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF](https://huggingface.co/Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF). To use another GGUF repo:

```bash
HF_MODEL_REPO_ID=owner/repo-name ./bootstrap.sh
```

**Port:** default is 28080. Override with `LLAMA_PORT=28081 ./start-llama-server.sh` and `LLAMA_PORT=28081 ./run-codex.sh exec "..."`.

**Context size / threads:** `LLAMA_CTX_SIZE=8192` and/or `LLAMA_THREADS=8` when starting the server (see `start-llama-server.sh`).

---

## Troubleshooting

| Issue | What to do |
|------|------------|
| `.codex/config.toml not found` | Run `./bootstrap.sh` first. |
| "Model server is not reachable" or Codex doesn't answer | Start the server: `./start-llama-server.sh`, wait until it's up, then run `./run-codex.sh exec "..."`. |
| Codex CLI not found | Install from Cursor (Preferences → Advanced → Install CLI) or npm; open a new terminal. |
| Port 28080 in use | Run `./stop-llama-server.sh`, wait a few seconds, try again. Or use another port: `LLAMA_PORT=28081 ./start-llama-server.sh` and `LLAMA_PORT=28081 ./run-codex.sh exec "..."`. |
| llama-server build fails | Ensure `cmake` and a C++ compiler are installed. On Linux: `sudo apt install build-essential cmake` (or equivalent). |

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
| `start-llama-server.sh` | Start the model server. |
| `stop-llama-server.sh` | Stop the model server. |
| `run-codex.sh` | Run Codex with this project's config. |
| `test-api.sh` | Test server response. |
| `models/`, `.venv/`, `.codex/`, `llama_bin/` | Created by bootstrap; copy them when moving the kit. |

**Make:** `make deps` (= bootstrap), `make clean` (remove generated content), `make test` (run checks; requires `codex` on PATH).

---

## License

MIT. See [LICENSE](LICENSE).
