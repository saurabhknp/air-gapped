# Portable Codex CLI + vLLM

Self-contained directory for running **Codex CLI** against a local **vLLM** server. Default model: **Nanbeige/Nanbeige4.1-3B**; you can choose another Hugging Face model or use the optional GGUF preset. All resources live inside this directory; copy to an air-gapped system and run without network or system-wide config.

- **CODEX_HOME** is set to this directory’s **`.codex`** so config, sessions, and history stay under the project and **`~/.codex` is never used** ([Advanced Config](https://developers.openai.com/codex/config-advanced#config-and-state-locations)).

## Prerequisites

- **uv** (Python): [install uv](https://docs.astral.sh/uv/getting-started/installation/)
- **Codex CLI**: Install from Cursor → Preferences → Advanced → **Install CLI** (so `codex` is on PATH). Run Codex via `./run-codex.sh`; it sets CODEX_HOME to this project’s `.codex` and uses `.codex/config.toml` (proxy provider, default model).

## 1. Bootstrap (once, on a machine with internet)

**Choose which model to download:**

| Option | Command | Model |
|--------|---------|--------|
| Default | `./bootstrap.sh` | Nanbeige/Nanbeige4.1-3B |
| Preset GGUF | `./bootstrap.sh 2` or `./bootstrap.sh gguf` | Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF |
| Any HF repo | `HF_MODEL_REPO_ID=owner/repo ./bootstrap.sh` or `./bootstrap.sh owner/repo` | Your chosen repo |

Bootstrap will:

- Create `.venv` and install `huggingface_hub` and `vllm`
- Download the selected model into `./models/<model_name>`
- Create `.codex/config.toml` and `.codex/model_info` (proxy provider, default model, port from VLLM_PORT or 28080)
- Use real files only (`local_dir_use_symlinks=False`) for copy-to-air-gapped portability

If the model repo is gated, set `HF_TOKEN` or run `huggingface-cli login` before `./bootstrap.sh`.

## 2. Copy to air-gapped host

Copy the **entire** directory (including `models/`, `.venv/`, `.codex/`). No network needed on the target.

## 3. Run on air-gapped (or same machine)

**Quick start (3 steps):**

```bash
./start-vllm.sh                    # Terminal 1: start server
./run-codex.sh exec "Your prompt"  # Terminal 2: run Codex (model auto-filled from config)
./stop-vllm.sh                     # when done: stop server
```

**Terminal 1 – start vLLM:** `./start-vllm.sh`

- **CPU instead of GPU:** `VLLM_DEVICE=cpu ./start-vllm.sh`

**Terminal 2 – run Codex:** Model is read from `.codex/config.toml`; no need to pass `--model` unless you override.

```bash
./run-codex.sh exec "Hello"
# With options: ./run-codex.sh exec --json -- 'Your prompt'
# Override model: ./run-codex.sh exec --model <model-id> "Hello"
```

**Stop vLLM:** `./stop-vllm.sh`

**If Codex has no response:** ensure vLLM is running (`./start-vllm.sh`), then run `./test-vllm-api.sh`. Codex uses the "proxy" provider in `.codex/config.toml` pointing at local vLLM.

## If vLLM runs out of memory (OOM)

`start-vllm.sh` already uses vLLM options to reduce OOM risk:

- **`--max-model-len auto`** — vLLM automatically picks the largest context length that fits in GPU memory (see [engine args](https://docs.vllm.ai/en/latest/configuration/engine_args/)).
- **`--gpu-memory-utilization 0.85`** — Uses 85% of GPU memory by default (vLLM default is 0.9); leaves some headroom.

If you still hit OOM, lower GPU utilization:

```bash
VLLM_GPU_MEMORY_UTILIZATION=0.75 ./start-vllm.sh
```

Or cap context length by adding `--max-model-len 4096` (or another value) to the `vllm serve` command in `start-vllm.sh`.

## Configuring Codex CLI

Codex reads project config from **`.codex/config.toml`** (created by bootstrap). You can edit it to tune model behavior and avoid the “Model metadata not found” warning.

**Config file location:** `./.codex/config.toml` (or `$CODEX_HOME/config.toml` when using this project).

**Useful keys** (see [Config basics](https://developers.openai.com/codex/config-basic) and [Advanced Config](https://developers.openai.com/codex/config-advanced)):

| Key | Description |
|-----|-------------|
| `model` | Default model id (must match vLLM’s `--served-model-name`). |
| `model_provider` | Provider name (this project uses `"proxy"` for vLLM). |
| `model_context_window` | Max context length (tokens). Example: `model_context_window = 262144`. Reduces “metadata not found” issues and caps context. |
| `model_verbosity` | `"low"` \| `"medium"` \| `"high"` — response length hint (Responses API). |
| `model_reasoning_summary` | e.g. `"none"` — control reasoning summaries. |

**Model metadata (context length, max output):** Codex can use a **model catalog** JSON for full metadata (context window, max output tokens, etc.). Without it, Codex may warn and use fallback values. To supply metadata for your local model:

1. Create a JSON file (e.g. `.codex/model_catalog.json`) describing your model (context window, max output, etc.). Format is provider-specific; see [Codex config reference](https://developers.openai.com/codex/config-reference) for `model_catalog_json`.
2. In `.codex/config.toml` add: `model_catalog_json = ".codex/model_catalog.json"` (path relative to project root or absolute).

**Per-request max output:** The API’s `max_tokens` (or `max_completion_tokens`) is sent per request; vLLM and Codex respect it. Codex does not set a global max output in config; use the catalog or leave it to the API default.

## Layout

| Path | Purpose |
|------|--------|
| `bootstrap.sh` | One-click fetch of model, venv, and Codex config (run once online) |
| `env.sh` | Exports CODEX_HOME, OPENAI_API_BASE, OPENAI_API_KEY (sourced by run-codex.sh) |
| `start-vllm.sh` | Start vLLM on port 28080 (override with VLLM_PORT) |
| `stop-vllm.sh` | Stop vLLM (uses `.codex/vllm.pid` when set by start-vllm.sh, else pgrep) |
| `run-codex.sh` | Run Codex with CODEX_HOME=.codex and .codex/config.toml (adds --skip-git-repo-check for exec) |
| `models/<name>/` | Model files (created by bootstrap; name from chosen repo) |
| `.venv/` | Python env with vLLM (created by bootstrap) |
| `scripts/codex-config.toml.template` | Codex config template (bootstrap writes .codex/config.toml from it) |
| `.codex/` | Codex config/sessions; config.toml, model_info, vllm.pid when vLLM running (CODEX_HOME) |

`models/`, `.venv/`, `.codex/`, `bin/` are in `.gitignore`; only code and config template are committed. Re-run `./bootstrap.sh` or `make deps` to recreate them.

## Make

| Target | Description |
|--------|--------------|
| `make clean` | Remove `.venv`, `models/`, `.codex/` (all fetched/generated content) |
| `make deps` | Run bootstrap: create venv, install deps, download model, create `.codex/config.toml` |
| `make upgrade` | Upgrade Python packages (huggingface_hub, vllm) to latest; run `make deps` first if `.venv` is missing |

## License

MIT. See [LICENSE](LICENSE).
