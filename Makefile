# Air-gapped Codex + vLLM: dependency and env management.
# Codex CLI is not a dependency of this repo; install from Cursor (Preferences -> Advanced -> Install CLI).

ROOT := $(CURDIR)
VENV := $(ROOT)/.venv
MODELS := $(ROOT)/models
CODEX_DIR := $(ROOT)/.codex

.PHONY: clean deps upgrade test help

help:
	@echo "Targets:"
	@echo "  clean   - Remove .venv, models/, .codex/ (all fetched/generated content)"
	@echo "  deps    - CPU-only bootstrap (default). Use 'make deps GPU=1' for CUDA/GPU."
	@echo "  upgrade - Upgrade Python packages; requires 'deps' first"
	@echo "  test    - Run full detection (start vLLM, API + Codex exec, stop, failure-path checks); requires 'deps' and codex on PATH"

clean:
	rm -rf $(VENV) $(MODELS) $(CODEX_DIR)
	@echo "[make] Removed .venv, models/, .codex/"

deps:
	@echo "[make] Running bootstrap.sh (venv + deps + model + .codex/config.toml) ..."
	./bootstrap.sh $(if $(GPU),gpu,)

upgrade:
	@test -d $(VENV) || (echo "[make] Run 'make deps' first." && exit 1)
	export VIRTUAL_ENV="$(VENV)" PATH="$(VENV)/bin:$$PATH" && uv pip install --upgrade huggingface_hub vllm
	@echo "[make] Upgraded huggingface_hub and vllm"

test:
	@./scripts/run_tests.sh
