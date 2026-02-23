# code-dispatcher Project Instructions

## Project Summary
code-dispatcher is a multi-backend AI coding toolkit: a Go CLI that dispatches tasks to `codex`/`claude`/`gemini` backends, paired with orchestration skills for structured development workflows — planning + parallel execution, iterative wave execution, multi-reviewer code review, issue-to-PR delivery, and bot-review triage.

## Tech Stack
- Go: main dispatcher program
- Python: install/uninstall scripts
- Bash: build and distribution script

## Repository Structure
- `code-dispatcher/`: Go source (main package and backend dispatch logic)
- `skills/`: Claude Code skills (`dev`, `wave`, `code-dispatcher`, `code-dispatcher-flash`, `code-council`, `github-issue-pr-flow`, `pr-review-reply`)
- `docs/`: documentation (`runtime-config.md`)
- `scripts/`: build scripts (`build-dist.sh`)
- `install.py` / `uninstall.py`: installer and uninstaller
- `dist/`: build outputs (gitignored)

## Development Commands
```bash
cd code-dispatcher && go test ./...
bash scripts/build-dist.sh
python3 install.py
```

## Code Conventions
- All backend execution must go through `code-dispatcher`; do not call `codex`, `claude`, or `gemini` directly.
- Single runtime config source: `~/.code-dispatcher/.env`.
- Prompt injection files: `~/.code-dispatcher/prompts/<backend>-prompt.md`.
