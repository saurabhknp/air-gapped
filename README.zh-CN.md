# Air-Gapped Codex + vLLM

**\[ [English](README.md) ]**

---

> **你的运维智能体。离线。一个文件夹。**  
> *把可携带的 AI 带进保密间——无云、无外网、不妥协。*

---

## 为什么需要它

隔离环境做运维：上不了网、带不了设备，文档查不了、AI 问不了；K8s 命令长、配置多，只能死记或打印带进去——又慢又容易错。**拷进一个文件夹**，在本地离线跑 Codex 级智能体：说一句「帮我查某某命名空间下异常 Pod」，自动生成命令、执行并给建议。无外网、无云。**不能联网的环境里，它就是你的离线运维专家。**

---

## 技术上它是什么

**Air-Gapped Codex + vLLM** 是一个**单目录、可携带**的套件：

- 在本地用 [vLLM](https://docs.vllm.ai/) 跑**本地大模型**——支持 **GPU 或 CPU**（无显卡也能用）。
- 用 **[Codex CLI](https://developers.openai.com/codex)**（OpenAI 的编程/运维智能体）连到这台本地模型，让你在**完全离线**的情况下，获得和用云端 API 时同等的智能体体验。
- 只需在**有网络的机器上**做一次准备（下载模型、安装依赖、生成配置），然后把**整个目录**拷到合规介质上带进工作区即可。目标环境**不需要任何外网**。

用于**部署、配置、写 runbook、排障**——不用出房间、不碰云。

---

## 快速开始（三步）

在项目目录下打开终端执行。

### 1. 一次性准备（在能联网的机器上）

```bash
./bootstrap.sh
```

会创建 Python 环境、下载默认模型（约 6GB）并生成配置。看到 `[bootstrap] Done. Next: ...` 即完成。

### 2. 启动模型服务

**此终端保持打开。**

```bash
./start-vllm.sh
```

等服务就绪（例如出现 “Uvicorn running on http://127.0.0.1:28080”）。首次启动可能需要 1–2 分钟。

### 3. 运行 Codex（在另一个终端）

```bash
./run-codex.sh exec "帮我写一个简单的 Web 应用的 Kubernetes Deployment YAML"
```

Codex 会使用本地模型。把引号里的内容换成你的真实任务——写配置、写脚本、排查问题都可以。

**用完后关服务：** 在运行 vLLM 的终端按 **Ctrl+C**，或在任意终端执行 `./stop-vllm.sh`。

---

## 拷进隔离/保密工作区

1. 在**能联网的机器**上执行 `./bootstrap.sh` 并等待完成。  
2. 将**整个**项目目录（含 `models/`、`.venv/`、`.codex/`）拷到合规介质上。  
3. 在工作区机器上（无需网络）：先运行 `./start-vllm.sh`，再在另一个终端运行 `./run-codex.sh exec "你的任务"`。

无云、无 API Key、无外网。

---

## 环境要求

| 要求 | 说明 |
|------|------|
| **uv** | [安装 uv](https://docs.astral.sh/uv/getting-started/installation/)（Python/环境管理）。验证：`uv --version`。 |
| **Codex CLI** | 在 **Cursor** 中：Preferences → Advanced → **Install CLI**；或通过 npm 安装。验证：`codex --version`。 |
| **GPU 或 CPU** | 有 GPU 更快；**仅 CPU 也支持**（例如 `VLLM_DEVICE=cpu ./start-vllm.sh`），适合没有显卡的办公/保密机。 |

---

## 常用命令一览

| 命令 | 作用 |
|------|------|
| `./bootstrap.sh` | 一次性准备（仅需执行一次，需要联网）。 |
| `./start-vllm.sh` | 启动本地模型服务（保持该终端开启）。 |
| `./run-codex.sh exec "任务"` | 用 Codex 执行你的任务，走本地服务。 |
| `./stop-vllm.sh` | 停止模型服务。 |
| `./test-vllm-api.sh` | 快速检查服务是否正常响应。 |

请始终在**本项目目录**下执行 `./run-codex.sh`，这样 Codex 会使用本项目的配置与状态，不会和 `~/.codex` 混用。

---

## 可选：换模型或仅用 CPU

**使用其他模型（如 GGUF 量化）：**

```bash
./bootstrap.sh 2          # 或：./bootstrap.sh gguf
# 然后照常执行 ./start-vllm.sh 和 ./run-codex.sh
```

**仅用 CPU（无 GPU）：**

```bash
VLLM_DEVICE=cpu ./start-vllm.sh
```

速度会慢一些，但在没有显卡的保密/办公机上可用。

---

## 常见问题

| 现象 | 处理 |
|------|------|
| `.codex/config.toml not found` | 先执行 `./bootstrap.sh`。 |
| “vLLM is not reachable” 或 Codex 无响应 | 先启动服务：`./start-vllm.sh`，等就绪后再执行 `./run-codex.sh exec "..."`。 |
| 找不到 Codex CLI | 在 Cursor 中安装（Preferences → Advanced → Install CLI）或通过 npm 安装，并重新打开终端。 |
| 端口 28080 被占用 | 执行 `./stop-vllm.sh`，等几秒再试；或换端口：`VLLM_PORT=28081 ./start-vllm.sh` 与 `VLLM_PORT=28081 ./run-codex.sh exec "..."`。 |
| 内存不足 (OOM) | 可减小上下文：`VLLM_MAX_MODEL_LEN=8192 ./start-vllm.sh`。 |

---

## 项目宪章与文档

- **[CHARTER.md](CHARTER.md)** — 项目初衷、目标用户与开发边界（宪章）。所有开发均需遵循。
- **[VERSIONS.md](VERSIONS.md)** — 版本基线（vLLM ≥ 0.16、Codex CLI）及官方文档链接。
- **[docs/README.md](docs/README.md)** — 技术说明（架构、bootstrap、CPU/GPU、配置）。
- **[README.md](README.md)** — 英文说明。

---

## 目录结构（参考）

| 路径 | 说明 |
|------|------|
| `CHARTER.md` | 项目宪章（愿景、原则、范围）。 |
| `VERSIONS.md` | 版本基线与文档链接。 |
| `docs/README.md` | 技术文档。 |
| `bootstrap.sh` | 一次性准备脚本。 |
| `start-vllm.sh` | 启动模型服务。 |
| `stop-vllm.sh` | 停止模型服务。 |
| `run-codex.sh` | 使用本项目配置运行 Codex。 |
| `test-vllm-api.sh` | 测试服务是否响应。 |
| `models/`、`.venv/`、`.codex/` | 由 bootstrap 生成；迁移时需一并拷贝。 |

**Make：** `make deps`（等同于 bootstrap）、`make clean`（清理生成内容）、`make test`（运行检测，需已安装并可用 `codex`）。

---

## 许可证

MIT。见 [LICENSE](LICENSE)。
