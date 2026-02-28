# Portable Codex CLI + vLLM (Nanbeige4.1-3B)

Self-contained directory for running **Codex CLI** against a local **vLLM** server (model: Nanbeige4.1-3B). All resources live inside this directory; copy it to any air-gapped system and run without network or system-wide config.

- **CODEX_HOME** is set to this directory’s **`.codex`** so config, sessions, and history stay under the project and **`~/.codex` is never used** ([Advanced Config](https://developers.openai.com/codex/config-advanced#config-and-state-locations)).

## Prerequisites

- **uv** (Python): [install uv](https://docs.astral.sh/uv/getting-started/installation/)
- **Codex CLI**: Install from Cursor → Preferences → Advanced → **Install CLI** (so `codex` is on PATH). Run Codex via `./run-codex.sh`; it sets CODEX_HOME to this project’s `.codex` and uses `.codex/config.toml` (proxy provider, default model).

## 1. Bootstrap (once, on a machine with internet)

```bash
./bootstrap.sh
```

This will:

- Create `.venv` and install `huggingface_hub` and `vllm`
- Download **Nanbeige/Nanbeige4.1-3B** into `./models/Nanbeige4.1-3B`
- Create `.codex/config.toml` from `scripts/codex-config.toml.template` (proxy provider, default model Nanbeige4.1-3B, port from VLLM_PORT or 28080)
- Download model with real files only (`local_dir_use_symlinks=False`) for copy-to-air-gapped portability

If the model repo is gated, set `HF_TOKEN` or run `huggingface-cli login` before `./bootstrap.sh`.

## 2. Copy to air-gapped host

Copy the **entire** directory (including `models/`, `.venv/`, `.codex/`). No network needed on the target.

## 3. Run on air-gapped (or same machine)

**Terminal 1 – start vLLM:**

```bash
./start-vllm.sh
```

**Terminal 2 – run Codex:**

```bash
./run-codex.sh exec --json --model <model-id> -- 'Your prompt'
```

To stop vLLM: `./stop-vllm.sh`

Get `<model-id>` from:

```bash
curl http://127.0.0.1:28080/v1/models
```

Example (model is auto-filled for local vLLM):

```bash
./run-codex.sh exec "Hello"
# Or with explicit model: ./run-codex.sh exec --model Nanbeige4.1-3B "Hello"
```

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

## Layout

| Path | Purpose |
|------|--------|
| `bootstrap.sh` | One-click fetch of model, venv, and Codex config (run once online) |
| `env.sh` | Exports CODEX_HOME, OPENAI_API_BASE, OPENAI_API_KEY (sourced by run-codex.sh) |
| `start-vllm.sh` | Start vLLM on port 28080 (override with VLLM_PORT) |
| `stop-vllm.sh` | Stop vLLM (uses `.codex/vllm.pid` when set by start-vllm.sh, else pgrep) |
| `run-codex.sh` | Run Codex with CODEX_HOME=.codex and .codex/config.toml (adds --skip-git-repo-check for exec) |
| `models/Nanbeige4.1-3B/` | Model files (created by bootstrap) |
| `.venv/` | Python env with vLLM (created by bootstrap) |
| `scripts/codex-config.toml.template` | Codex config template (bootstrap writes .codex/config.toml from it) |
| `.codex/` | Codex config/sessions; config.toml + vllm.pid when vLLM running (CODEX_HOME) |

`models/`, `.venv/`, `.codex/`, `bin/` are in `.gitignore`; only code and config template are committed. Re-run `./bootstrap.sh` or `make deps` to recreate them.

## Make

| Target | Description |
|--------|--------------|
| `make clean` | Remove `.venv`, `models/`, `.codex/` (all fetched/generated content) |
| `make deps` | Run bootstrap: create venv, install deps, download model, create `.codex/config.toml` |
| `make upgrade` | Upgrade Python packages (huggingface_hub, vllm) to latest; run `make deps` first if `.venv` is missing |

## License

MIT. See [LICENSE](LICENSE).
