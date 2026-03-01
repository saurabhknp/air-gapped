# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.2.0] - 2026-03-01

### Added

- **CPU-first defaults:** Default install is CPU-only (no CUDA). Use `VLLM_USE_GPU=1 ./bootstrap.sh` or `./bootstrap.sh gpu` for GPU/CUDA.
- **Default model:** GGUF quantized `Edge-Quant/Nanbeige4.1-3B-Q4_K_M-GGUF` (~2GB, CPU-friendly).
- **Auto-detect CPU resources:** When running in CPU mode, `start-vllm.sh` auto-detects logical CPU count and total RAM, and sets `OMP_NUM_THREADS` and `VLLM_CPU_KVCACHE_SPACE` (~50% RAM, min 2 GiB). Override with `VLLM_CPU_NUM_THREADS` and `VLLM_CPU_KVCACHE_SPACE` if needed.
- **Install mode tracking:** `.codex/install_mode` records whether bootstrap was CPU (0) or GPU (1). `start-vllm.sh` warns if you set `VLLM_DEVICE=cuda` but the project was bootstrapped CPU-only.
- **CHANGELOG.md** (this file).

### Changed

- **Bootstrap:** Default is CPU-only install (PyTorch from CPU index on Linux when possible; vLLM may still pull CUDA wheels due to pinned deps). Runtime remains CPU unless `VLLM_DEVICE=cuda`.
- **start-vllm.sh:** Default device is `cpu`. CPU thread and KV cache size are auto-set when not provided.
- **Makefile:** `make deps` = CPU bootstrap; `make deps GPU=1` = GPU bootstrap.
- **Test script:** Wait for vLLM ready extended to 10 min for CPU + GGUF first load.

### Documentation

- **docs/README.md:** Bootstrap CPU/GPU modes, CPU inference control (threads, KV cache), install mode.
- **README.md / README.zh-CN.md:** Short copy, default CPU + GGUF, optional GPU/full model, link to CPU tuning.

---

## [0.1.0] - 2026-02-28

### Added

- Initial portable air-gapped Codex + vLLM kit: bootstrap, start/stop vLLM, run Codex against local model.
- Support for GPU and CPU (default model and device evolved in 0.2.0).
- Project charter (CHARTER.md), version baseline (VERSIONS.md), technical docs (docs/README.md).
