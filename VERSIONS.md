# Dependency and version baseline

This file records the **current version baseline** used and tested for this project. Check these when upgrading or debugging.

---

## vLLM

| Item | Value |
|------|--------|
| **Baseline version** | **0.16.0** |
| **PyPI** | https://pypi.org/project/vllm/ |
| **Latest release** | https://github.com/vllm-project/vllm/releases/latest |
| **Documentation** | https://docs.vllm.ai/en/latest/ |
| **Quickstart** | https://docs.vllm.ai/en/latest/getting_started/quickstart.html |
| **Installation** | https://docs.vllm.ai/en/latest/getting_started/installation.html |

**Why 0.16+:** vLLM 0.16+ exposes the **Responses API** (`/v1/responses`), which Codex CLI uses when `wire_api = "responses"` in `.codex/config.toml`. Older vLLM only had `/v1/chat/completions` and would return 404 for Codex.

**Project constraint:** `vllm>=0.16.0` in `pyproject.toml` and `bootstrap.sh`.

---

## Codex CLI

| Item | Value |
|------|--------|
| **Baseline version** | **0.106.0** (as of 2026-02-26; install from Cursor or npm) |
| **Install (Cursor)** | Cursor → Preferences → Advanced → **Install CLI** |
| **Install (npm)** | `npm install -g @openai/codex@0.106.0` |
| **Changelog** | https://developers.openai.com/codex/changelog |
| **Documentation** | https://developers.openai.com/codex |
| **CLI overview** | https://developers.openai.com/codex/cli |
| **CLI reference** | https://developers.openai.com/codex/cli/reference |
| **Config basics** | https://developers.openai.com/codex/config-basic |
| **Advanced config** | https://developers.openai.com/codex/config-advanced |
| **Config reference** | https://developers.openai.com/codex/config-reference |

Codex is **not** a Python dependency of this repo; it is installed separately (Cursor or npm) and must be on `PATH`. This project only configures Codex via `CODEX_HOME` and `.codex/config.toml` to point at the local vLLM server.

---

## Other deps (from pyproject.toml)

- **huggingface_hub** ≥ 0.20.0 — used by `scripts/download_model.py` to fetch models.

---

*Last updated: 2026-02-28 (baseline: vLLM 0.16.0, Codex CLI 0.106.0).*
