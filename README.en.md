# code-dispatcher

<p align="center">
  <a href="README.md">中文</a> | <strong>English</strong>
</p>

> Receive task → select backend → build args → dispatch execution → collect results. That's dispatch.

What you get:
- `dev` skill & command: requirements clarification → plan → select backend → parallel execution → verification
- `code-dispatcher` executor & skill: Go executor; unified 3 backends `codex/claude/gemini`; core mechanisms `--parallel` & `--resume`; usage guide (for AI consumption, full and flash variants)
- `code-council` skill: multi-perspective parallel code review (2–3 AI reviewers in parallel + host agent final pass)

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
python3 install.py --repo zhu-jl18/code-dispatcher --release-tag latest
```

Installer outputs:
- `~/.code-dispatcher/.env` (single runtime config source)
- `~/.code-dispatcher/prompts/*-prompt.md` (per-backend placeholders)
- `~/.code-dispatcher/bin/code-dispatcher` (or `.exe` on Windows)

Not automated (manual by design):
- No auto-copy of `skills/`, `dev-workflow/commands`, or `dev-workflow/agents` into your target CLI root/project scope
- Manually copy what you need based on your target CLI:
  - **Skills**: pick from `skills/*` (for example: `skills/dev`, `skills/code-dispatcher` or `skills/code-dispatcher-flash`, `skills/code-council`)
  - **/dev command (Claude Code, etc.)**: use `dev-workflow/commands/dev.md` and `dev-workflow/agents/*`

Notes:
- Running `install.py` under WSL installs the Linux binary; on macOS (Apple Silicon) it installs the Darwin arm64 binary; on Windows it installs the `.exe`.
- Requires network access to GitHub Releases; use `--skip-dispatcher` if you only need runtime config/assets.

## Local Build (Optional)

```bash
bash scripts/build-dist.sh
```

Local artifacts (not tracked by git by default):
- `dist/code-dispatcher-linux-amd64`
- `dist/code-dispatcher-darwin-arm64`
- `dist/code-dispatcher-windows-amd64.exe`

## Prompt Injection (Default-On, Empty = No-Op)

Default prompt placeholder files:
- `~/.code-dispatcher/prompts/codex-prompt.md`
- `~/.code-dispatcher/prompts/claude-prompt.md`
- `~/.code-dispatcher/prompts/gemini-prompt.md`

Behavior:
- code-dispatcher loads the per-backend prompt and prepends it only if it has non-empty content.
- Empty/whitespace-only or missing prompt files behave like "no injection".

Runtime behavior (approval/bypass flags, timeout, parallel propagation rules):
- `docs/runtime-config.md`

## Usage

In Claude Code:
```text
/dev "implement X"
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
