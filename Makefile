# Air-gapped Codex + vLLM: dependency and env management.
# Codex CLI is not a dependency of this repo; install from Cursor (Preferences -> Advanced -> Install CLI).

ROOT := $(CURDIR)
VENV := $(ROOT)/.venv
MODELS := $(ROOT)/models
CODEX_DIR := $(ROOT)/.codex

.PHONY: clean deps upgrade help

help:
	@echo "Targets:"
	@echo "  clean   - Remove .venv, models/, .codex/ (all fetched/generated content)"
	@echo "  deps    - Create .venv, install Python deps, download model, create .codex/config.toml (run bootstrap.sh)"
	@echo "  upgrade - Upgrade Python packages (huggingface_hub, vllm) to latest; requires 'deps' first"

clean:
	rm -rf $(VENV) $(MODELS) $(CODEX_DIR)
	@echo "[make] Removed .venv, models/, .codex/"

deps:
	@echo "[make] Running bootstrap.sh (venv + deps + model + .codex/config.toml) ..."
	./bootstrap.sh

upgrade:
	@test -d $(VENV) || (echo "[make] Run 'make deps' first." && exit 1)
	export VIRTUAL_ENV="$(VENV)" PATH="$(VENV)/bin:$$PATH" && uv pip install --upgrade huggingface_hub vllm
	@echo "[make] Upgraded huggingface_hub and vllm"
