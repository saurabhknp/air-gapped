# Air-gapped Codex + llama.cpp: dependency and env management.
# Codex CLI is not a dependency of this repo; install from Cursor (Preferences -> Advanced -> Install CLI).

ROOT := $(CURDIR)
VENV := $(ROOT)/.venv
MODELS := $(ROOT)/models
CODEX_DIR := $(ROOT)/.codex
LLAMA_BIN := $(ROOT)/llama_bin

.PHONY: clean deps upgrade test help

help:
	@echo "Targets:"
	@echo "  clean   - Remove .venv, models/, .codex/, llama_bin/ (all fetched/generated content)"
	@echo "  deps    - Bootstrap: download llama.cpp binary (CPU x64) + model + .codex config"
	@echo "  upgrade - Upgrade huggingface_hub; requires 'deps' first"
	@echo "  test    - Start llama-server, API + Codex exec, stop, failure-path checks; requires 'deps' and codex on PATH"

clean:
	rm -rf $(VENV) $(MODELS) $(CODEX_DIR) $(LLAMA_BIN)
	@echo "[make] Removed .venv, models/, .codex/, llama_bin/"

deps:
	@echo "[make] Running bootstrap.sh (llama.cpp binary + model + .codex/config.toml) ..."
	./bootstrap.sh

upgrade:
	@test -d $(VENV) || (echo "[make] Run 'make deps' first." && exit 1)
	export VIRTUAL_ENV="$(VENV)" PATH="$(VENV)/bin:$$PATH" && uv pip install --upgrade huggingface_hub
	@echo "[make] Upgraded huggingface_hub"

test:
	@./scripts/run_tests.sh
