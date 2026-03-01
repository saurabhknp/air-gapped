# Portable Codex CLI + vLLM

Run **Codex CLI** (Cursor’s coding agent) with a **local AI model** on your machine. No cloud API key needed. Everything stays in this folder. The project uses **vLLM ≥ 0.16** so the server supports the Responses API (`/v1/responses`) that Codex expects.

---

## What you need before starting

1. **uv** (installs Python and packages)  
   - Install: https://docs.astral.sh/uv/getting-started/installation/  
   - Check: run `uv --version` in a terminal.

2. **Codex CLI** (the command you’ll run)  
   - In **Cursor**: open **Preferences** → **Advanced** → click **Install CLI**.  
   - Check: open a new terminal and run `codex --version`.

3. **A GPU** is recommended (faster). If you only have a CPU, you can still use it; see [Using CPU instead of GPU](#using-cpu-instead-of-gpu) below.

---

## Quick start (3 steps)

Do these in order. Use a terminal opened in this project folder.

### Step 1: One-time setup (only once, needs internet)

```bash
./bootstrap.sh
```

- This creates a Python environment, downloads the default model (~6GB), and writes config.  
- It can take several minutes. When it finishes, you’ll see: `[bootstrap] Done. Next: ...`

### Step 2: Start the model server

**Leave this terminal open.** Run:

```bash
./start-vllm.sh
```

- Wait until you see the server is running (e.g. “Uvicorn running on http://127.0.0.1:28080”).  
- The first start can take 1–2 minutes to load the model.

### Step 3: Run Codex (in a second terminal)

Open a **new** terminal, go to the same project folder, then run:

```bash
./run-codex.sh exec "Write a Python function that adds two numbers"
```

- Codex will use the local model you started in Step 2.  
- Replace the quoted text with any task you want.

When you’re done, in the terminal where vLLM is running press **Ctrl+C**, or in any terminal run:

```bash
./stop-vllm.sh
```

---

## What each command does

| Command | What it does |
|--------|----------------|
| `./bootstrap.sh` | First-time setup: installs tools and downloads the model (run once). |
| `./start-vllm.sh` | Starts the local model server (keep this terminal open). |
| `./run-codex.sh exec "your task"` | Runs Codex with your task; uses the local server. |
| `./stop-vllm.sh` | Stops the model server. |
| `./test-vllm-api.sh` | Quick check that the server is responding (optional). |

Always run `./run-codex.sh` from **this project folder**. Don’t run the raw `codex` command from here; use the script so it uses this project’s config.

---

## Troubleshooting

### “.codex/config.toml not found”

You haven’t run setup yet. Run:

```bash
./bootstrap.sh
```

then try again.

---

### “vLLM is not reachable” or Codex doesn’t answer

The model server isn’t running or isn’t ready yet.

1. In one terminal run: `./start-vllm.sh`  
2. Wait until you see the server is up (e.g. “Uvicorn running …”).  
3. Then in another terminal run: `./run-codex.sh exec "your task"`

To test the server only:

```bash
./test-vllm-api.sh
```

If that fails, start vLLM first and wait a bit, then run the test again.

---

### “No such file or directory” when running a script

You’re not in the project folder. In the terminal run:

```bash
cd /path/to/air-gapped
```

(replace with the real path to this folder), then run the command again.

---

### “Codex CLI not found on PATH”

Codex isn’t installed. In Cursor: **Preferences** → **Advanced** → **Install CLI**, then open a **new** terminal and try again.

---

### “Port 28080 is already in use”

Something else is using that port, or an old vLLM is still running. Stop it:

```bash
./stop-vllm.sh
```

Wait a few seconds, then run `./start-vllm.sh` again. If it still fails, try another port:

```bash
VLLM_PORT=28081 ./start-vllm.sh
```

Then when you run Codex, use the same port:

```bash
VLLM_PORT=28081 ./run-codex.sh exec "your task"
```

---

### Server runs out of memory (OOM) or “KV cache” error

The default context length may be too large for your GPU. Start vLLM with a smaller limit:

```bash
VLLM_MAX_MODEL_LEN=8192 ./start-vllm.sh
```

You can try `4096` or `16384` if needed.

---

## Optional: choose a different model

By default the project uses **Nanbeige/Nanbeige4.1-3B**. To use another model, run bootstrap **once** with one of these:

| What you want | Command |
|---------------|--------|
| Default (recommended) | `./bootstrap.sh` |
| GGUF quantized model | `./bootstrap.sh 2` or `./bootstrap.sh gguf` |
| Another Hugging Face model | `./bootstrap.sh owner/model-name` |

Example for a different model:

```bash
./bootstrap.sh 2
```

Then use `./start-vllm.sh` and `./run-codex.sh` as before.

---

## Using CPU instead of GPU

If you don’t have a GPU or want to force CPU:

```bash
VLLM_DEVICE=cpu ./start-vllm.sh
```

It will be slower. Some setups may show tokenizer errors; if so, try the default GPU path or a different vLLM version.

---

## Copying to another machine (air-gapped)

1. On a machine **with internet**: run `./bootstrap.sh` and wait for it to finish.  
2. Copy the **entire** project folder (including `models/`, `.venv/`, `.codex/`).  
3. On the other machine (no network needed): run `./start-vllm.sh` and then `./run-codex.sh exec "..."` as in Quick start.

---

## Configuring Codex (optional)

The file `.codex/config.toml` is created by bootstrap. You can edit it to change the default model or context length. Main keys:

- **model** — Model name (must match what vLLM serves).  
- **model_context_window** — Max context length in tokens (e.g. `32768`).

To reduce “Model metadata not found” warnings, you can set `model_context_window` to a number (e.g. `32768`). See [Codex config](https://developers.openai.com/codex/config-basic) for more options.

---

## Project layout (reference)

| Path | Purpose |
|------|--------|
| `VERSIONS.md` | Version baseline (vLLM, Codex) and doc links |
| `bootstrap.sh` | One-time setup (run once) |
| `start-vllm.sh` | Start the model server |
| `stop-vllm.sh` | Stop the model server |
| `run-codex.sh` | Run Codex with this project’s config |
| `test-vllm-api.sh` | Test that the server answers |
| `models/` | Downloaded model files (created by bootstrap) |
| `.venv/` | Python environment (created by bootstrap) |
| `.codex/` | Codex config and state for this project |

---

## Make commands (optional)

If you use `make`:

- `make deps` — Same as `./bootstrap.sh`  
- `make clean` — Remove `.venv`, `models/`, `.codex/` (start over)  
- `make test` — Start vLLM, run API test and checks, then stop (requires `codex` on PATH)

---

## Known issues

- **Proxy:** If you use a SOCKS proxy (`ALL_PROXY=socks5://...`), bootstrap temporarily unsets it for the model download so the download works with an HTTP proxy.  
- **Responses API:** This project uses **vLLM ≥ 0.16** so the server exposes `/v1/responses`, which Codex uses when `wire_api = "responses"` in `.codex/config.toml`. Older vLLM only had `/v1/chat/completions` and would return 404 for Codex.  
- **CPU / GGUF:** Some vLLM + transformers combinations can fail on CPU or with certain GGUF models. If you see tokenizer or path errors, use GPU and the default model first.

---

## Version baseline and docs

For the exact versions and doc links used as the current baseline, see **[VERSIONS.md](VERSIONS.md)**:

- **vLLM** ≥ 0.16.0 — [docs](https://docs.vllm.ai/en/latest/), needed for `/v1/responses` (Codex).
- **Codex CLI** — install from Cursor or [changelog](https://developers.openai.com/codex/changelog); [CLI reference](https://developers.openai.com/codex/cli/reference), [config](https://developers.openai.com/codex/config-advanced).

---

## License

MIT. See [LICENSE](LICENSE).
