# code-dispatcher-toolkit

<p align="center">
  <strong>中文</strong> | <a href="README.en.md">English</a>
</p>

> 基于 `code-dispatcher` CLI 构建的多后端 AI 编码工具集：执行器 + 编排 skill + 扩展模板。
>
> 接收任务 → 选后端 → 构建参数 → 分发执行 → 收集结果。这就是 dispatch。

你会得到什么：
- `dev` skill：需求澄清 → 计划 → 选择后端 → 并行执行（DAG 调度） → 验证
- `wave` skill：迭代式平级并行执行策略（host agent 每波动态拆任务 → 并行派单 → 看结果 → 下一波）
- `code-dispatcher` executor & skill：Go 写的执行器；统一 3 个后端 `codex/claude/gemini`；核心机制 `--parallel` & `--resume`；配套使用指南（给 AI 看的，分 full 和 flash 两版）
- `code-council` skill：多视角并行代码评审（2–3 个 AI reviewer 并行 + host agent 终审）
- `github-issue-pr-flow` skill：自主 Issue → PR 交付流程（分解 Issue → 实现 → 开 PR → 处理 review → squash merge）
- `pr-review-reply` skill：自主处理 PR 上的 bot review（Gemini / CodeRabbit 等）——验证 → 修复或反驳 → 回复线程 → resolve
- `cc-cx-review-loop` 扩展：实现 → 自动 review（code-dispatcher 并行跑 Diff + Holistic 两个独立 reviewer） → 处理反馈 → 完成

## 后端定位（仅推荐，可自由指定）

- `codex`：复杂逻辑、bug 修复、优化重构
- `claude`：快速任务、review、补充分析
- `gemini`：前端 UI/UX 原型、样式和交互细化
- 调用入口约束：后端都只通过 `code-dispatcher` 调用；不要直接调用 `codex` / `claude` / `gemini` 命令。


## 安装（WSL2/Linux + macOS + Windows）

默认安装方式：从 GitHub Release 的 `latest` 标签下载当前平台二进制（安装时不需要 Go）。

```bash
python3 install.py
```

可选参数：
```bash
python3 install.py --install-dir ~/.code-dispatcher --force
python3 install.py --skip-dispatcher
python3 install.py --repo zhu-jl18/code-dispatcher-toolkit --release-tag latest
```

安装器会做这些事：
- `~/.code-dispatcher/.env`：运行时唯一配置源
- `~/.code-dispatcher/prompts/*-prompt.md`：每个后端的默认 prompt 模板（可编辑，置空则禁用注入）
- `~/.code-dispatcher/bin/code-dispatcher`（Windows 上是 `.exe`）

不会自动做的事（必须手动）：
- 不会自动复制 `skills/` 到你的目标 CLI root 或 project scope
- 需要按你的目标 CLI 自行手动复制：
  - 从本仓库 `skills/*` 里挑需要的（例如 `skills/dev`、`skills/wave`、`skills/code-dispatcher` 或 `skills/code-dispatcher-flash`、`skills/code-council`、`skills/github-issue-pr-flow`、`skills/pr-review-reply`、`skills/cc-cx-review-loop`）
- 不会自动注入 `memory/CLAUDE-add.md` 到你的用户级配置
  - 该文件包含 `/dev` 工作流约定（Claude Code 负责规划和验证，编辑和测试必须通过 code-dispatcher skill 执行）
  - 需要手动将其内容追加到你自己的 `~/.claude/CLAUDE.md`（Claude Code）或 `AGENTS.md`（Codex 等）中

提示：
- 在 WSL 里运行 `install.py` 会安装 Linux 二进制；在 macOS（Apple Silicon）里运行会安装 Darwin arm64 二进制；在 Windows 里运行会安装 Windows `.exe`。
- 需要网络访问 GitHub Release；如只想更新配置文件，使用 `--skip-dispatcher`。
- Windows PATH 注意：不同 host agent 使用不同 shell。PowerShell/cmd 读 Windows 用户 PATH；Git Bash（如 Claude Code）需要在 `~/.bashrc` 中加 `export PATH="$HOME/.code-dispatcher/bin:$PATH"`。`install.py` 会打印两种 shell 的设置方法。

## 本地构建（可选）

```bash
bash scripts/build-dist.sh
```

本地构建产物（默认不提交到 git）：
- `dist/code-dispatcher-linux-amd64`
- `dist/code-dispatcher-darwin-arm64`
- `dist/code-dispatcher-windows-amd64.exe`

## Prompt 注入（默认开启）

每个后端一个 prompt 文件，安装时从仓库 `prompts/` 目录复制默认内容：
- `~/.code-dispatcher/prompts/codex-prompt.md`
- `~/.code-dispatcher/prompts/claude-prompt.md`
- `~/.code-dispatcher/prompts/gemini-prompt.md`

默认内容告诉后端：你是被 code-dispatcher 调度的 worker，这是一次 end-to-end 调用，不要中途停下，自由探索代码库获取上下文。

规则：
- code-dispatcher 会读取对应后端的 prompt 文件；只有在内容非空时才会 prepend 到任务前面
- 文件不存在 / 只有空白字符：等价“无注入”
- 要自定义：直接编辑 `~/.code-dispatcher/prompts/` 下的文件，或修改仓库 `prompts/` 目录后重新运行 `install.py --force`

运行时配置（审批/绕过、超时、并行传播规则、后端 model 指定）详见：
- `docs/runtime-config.md`

可选：在 `~/.code-dispatcher/.env` 中指定后端使用的 model：
```text
CODE_DISPATCHER_GEMINI_MODEL=gemini-2.5-pro
CODE_DISPATCHER_CODEX_MODEL=o3
```
不设置则使用各 CLI 自身默认值。Claude 不支持通过 dispatcher 指定 model。

## 使用

开发工作流（DAG 一次性派单）：
```text
/dev "实现 X"
```

开发工作流（迭代波次并行）：
```text
/wave "实现 X"
```

代码评审：
```text
Review @src/auth/ using code-council
```

## 开发/测试

```bash
cd code-dispatcher
go test ./...
```

## 致谢

原始灵感以及部分初始代码来源 [`cexll/myclaude`](https://github.com/cexll/myclaude)，特此感谢。
