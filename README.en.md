# code-dispatcher

<p align="center">
  <a href="README.md">中文</a> | <strong>English</strong>
</p>

> Receive task → select backend → build args → dispatch execution → collect results. That's dispatch.

What you get:
- `dev` skill: requirements clarification → plan → select backend → parallel execution (DAG scheduling) → verification
- `wave` skill: iterative flat-parallel execution strategy (host agent dynamically decomposes each wave → parallel dispatch → review results → next wave)
- `code-dispatcher` executor & skill: Go executor; unified 3 backends `codex/claude/gemini`; core mechanisms `--parallel` & `--resume`; usage guide (for AI consumption, full and flash variants)
- `code-council` skill: multi-perspective parallel code review (2–3 AI reviewers in parallel + host agent final pass)
- `github-issue-pr-flow` skill: autonomous issue-to-PR delivery (decompose → implement → open PR → handle reviews → squash merge)
- `pr-review-reply` skill: autonomous bot-review triage on PRs (Gemini / CodeRabbit etc.) — verify → fix or rebut → reply in thread → resolve
- `cc-cx-review-loop` extension: implement → auto-review (code-dispatcher runs Diff + Holistic reviewers in parallel) → address feedback → done

## Backend Positioning (Recommended)

- `codex`: complex logic, bug fixes, optimization & refactoring
- `claude`: quick tasks, review, supplementary analysis
- `gemini`: frontend UI/UX prototyping, styling, and interaction polish
- Invocation rule: all backends must be invoked through `code-dispatcher`; do not call `codex` / `claude` / `gemini` directly.

## Install (WSL2/Linux + macOS + Windows)

Default install path: download the current-platform binary from GitHub Release tag `latest` (no Go required).

```bash
python3 install.py
```

Optional:
```bash
python3 install.py --install-dir ~/.code-dispatcher --force
python3 install.py --skip-dispatcher
python3 install.py --repo zhu-jl18/code-dispatcher-toolkit --release-tag latest
```

Installer outputs:
- `~/.code-dispatcher/.env` (single runtime config source)
- `~/.code-dispatcher/prompts/*-prompt.md` (per-backend default prompt templates; clear to disable injection)
- `~/.code-dispatcher/bin/code-dispatcher` (or `.exe` on Windows)

Not automated (manual by design):
- No auto-copy of `skills/` into your target CLI root/project scope
- Manually copy what you need based on your target CLI:
  - Pick from `skills/*` (for example: `skills/dev`, `skills/wave`, `skills/code-dispatcher` or `skills/code-dispatcher-flash`, `skills/code-council`, `skills/github-issue-pr-flow`, `skills/pr-review-reply`, `skills/cc-cx-review-loop`)

Notes:
- Running `install.py` under WSL installs the Linux binary; on macOS (Apple Silicon) it installs the Darwin arm64 binary; on Windows it installs the `.exe`.
- Requires network access to GitHub Releases; use `--skip-dispatcher` if you only need runtime config/assets.
- Windows PATH: different host agents use different shells. PowerShell/cmd reads the Windows user PATH; Git Bash (e.g. Claude Code) requires `export PATH="$HOME/.code-dispatcher/bin:$PATH"` in `~/.bashrc`. `install.py` prints setup instructions for both shells.

## Local Build (Optional)

```bash
bash scripts/build-dist.sh
```

Local artifacts (not tracked by git by default):
- `dist/code-dispatcher-linux-amd64`
- `dist/code-dispatcher-darwin-arm64`
- `dist/code-dispatcher-windows-amd64.exe`

## Prompt Injection (Default-On)

Per-backend prompt files, installed from the repo `prompts/` directory with default content:
- `~/.code-dispatcher/prompts/codex-prompt.md`
- `~/.code-dispatcher/prompts/claude-prompt.md`
- `~/.code-dispatcher/prompts/gemini-prompt.md`

Defaults tell each backend: you are a worker dispatched by code-dispatcher, this is an end-to-end call, don't stop midway, freely explore the codebase for context.

Behavior:
- code-dispatcher loads the per-backend prompt and prepends it only if it has non-empty content.
- Empty/whitespace-only or missing prompt files behave like "no injection".
- To customize: edit files under `~/.code-dispatcher/prompts/` directly, or modify the repo `prompts/` dir and re-run `install.py --force`.

Runtime behavior (approval/bypass flags, timeout, parallel propagation rules, backend model override):
- `docs/runtime-config.md`

Optional: specify the model each backend should use in `~/.code-dispatcher/.env`:
```text
CODE_DISPATCHER_GEMINI_MODEL=gemini-2.5-pro
CODE_DISPATCHER_CODEX_MODEL=o3
```
Leave unset to use each CLI's default. Claude does not support model override via dispatcher.

## Usage

Development workflow (one-shot DAG):
```text
/dev "implement X"
```

Development workflow (iterative waves):
```text
/wave "implement X"
```

Code review:
```text
Review @src/auth/ using code-council
```

## Dev

```bash
cd code-dispatcher
go test ./...
```

## Acknowledgments

Original inspiration and partial code from [`cexll/myclaude`](https://github.com/cexll/myclaude), with thanks.
