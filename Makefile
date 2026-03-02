# Air-gapped Codex + llama.cpp: dependency and env management.
# Codex CLI is not a dependency of this repo; install from Cursor (Preferences -> Advanced -> Install CLI).

ROOT := $(CURDIR)
VENV := $(ROOT)/.venv
MODELS := $(ROOT)/models
CODEX_DIR := $(ROOT)/.codex
LLAMA_BIN := $(ROOT)/llama_bin

.PHONY: clean deps upgrade test diagnose proxy help

help:
	@echo "Targets:"
	@echo "  clean     - Remove .venv, models/, .codex/, llama_bin/ (all fetched/generated content)"
	@echo "  deps      - Bootstrap: llama.cpp (CPU) + model + .codex config; USE_VLLM=1 for vLLM (GPU)"
	@echo "  proxy     - Build codex-proxy (Responses API → Chat Completions converter)"
	@echo "  upgrade   - Upgrade huggingface_hub; requires 'deps' first"
	@echo "  test      - Start llama-server, API + Codex exec, stop, failure-path checks; requires 'deps' and codex on PATH"
	@echo "  test-vllm - Same as test but for GPU: start vLLM + proxy, API, Codex exec, stop; requires USE_VLLM=1 deps"
	@echo "  diagnose  - Backend vs proxy checks (direct, via proxy, streaming); run with server already up"

proxy:
	@echo "[make] Building codex-proxy..."
	cd $(ROOT)/codex-proxy && go mod tidy && go build -o codex-proxy .
	@echo "[make] Built codex-proxy/codex-proxy"

clean:
	rm -rf $(VENV) $(MODELS) $(CODEX_DIR) $(LLAMA_BIN)
	rm -f $(ROOT)/codex-proxy/codex-proxy
	@echo "[make] Removed .venv, models/, .codex/, llama_bin/, codex-proxy binary"

deps: proxy
	@echo "[make] Running bootstrap.sh (llama.cpp + model + .codex; USE_VLLM=1 for GPU) ..."
	USE_VLLM=$(USE_VLLM) ./bootstrap.sh

upgrade:
	@test -d $(VENV) || (echo "[make] Run 'make deps' first." && exit 1)
	export VIRTUAL_ENV="$(VENV)" PATH="$(VENV)/bin:$$PATH" && uv pip install --upgrade huggingface_hub
	@echo "[make] Upgraded huggingface_hub"

test:
	@CODEX_EXEC_TIMEOUT=$${CODEX_EXEC_TIMEOUT:-600} ./scripts/run_tests.sh

test-vllm:
	@CODEX_EXEC_TIMEOUT=$${CODEX_EXEC_TIMEOUT:-300} ./scripts/run_tests_vllm.sh

diagnose:
	@./scripts/diagnose_backend_proxy.sh
