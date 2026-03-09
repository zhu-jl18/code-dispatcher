# Harness Bundle

`harness` is a Claude Code long-running session skill+hook bundle for work that must survive context resets, retries, and multi-session progress tracking.

This is the `code-dispatcher-toolkit` port of the original harness idea:
- the skill defines the state machine and recovery rules
- project hooks keep Claude from stopping too early
- runtime state is consolidated under `.harness/`

It is complementary to `code-dispatcher`, not a replacement. Use harness when the Claude host session needs durable state; use `code-dispatcher` inside harnessed tasks when you want backend workers to do the implementation or review work.

## Bundle Contents

- `SKILL.md`: harness protocol and recovery rules
- `settings.json`: Claude Code hook config snippet to merge into project settings
- `hooks/`: Python hook handlers (`Stop`, `SessionStart`, `TeammateIdle`, `SubagentStop`, self-reflect)
- `tests/`: hook tests and a basic e2e harness scenario

## Install

1. Install the skill itself into your Claude skill search path.
   - Example targets: `~/.claude/skills/harness` or `<project>/.claude/skills/harness`
2. Copy this bundle's `hooks/` into the target project's `.claude/` directory.
3. Merge `settings.json` into the target project's `.claude/settings.json` or `.claude/settings.local.json`.
4. Ensure `python3` is available to Claude Code.

Suggested project structure:

```text
<project>/.claude/
├── hooks/
│   ├── _harness_common.py
│   ├── harness-claim.py
│   ├── harness-renew.py
│   ├── harness-sessionstart.py
│   ├── harness-stop.py
│   ├── harness-subagentstop.py
│   ├── harness-teammateidle.py
│   └── self-reflect-stop.py
└── settings.local.json (or settings.json)
```

## Dependencies

- Claude Code project hooks
- `python3`
- `git`
- shell utilities used by the protocol (`bash`, `timeout` or `gtimeout` on macOS)
- any task-specific `validation.command`

The core hook logic does not require `code-dispatcher`, but harnessed tasks can call `code-dispatcher` when backend delegation is useful.

## Usage

Use the original harness skill protocol directly. In the original prompt language, the workflow stages are expressed as:

- `/harness init <project-path>`
- `/harness add "task description"`
- `/harness status`
- `/harness run`

In this toolkit port, those names remain part of the skill protocol; no extra project-level slash-command wrappers are installed.

## Runtime Artifacts

Harness writes runtime state into `.harness/` under the project root:

- `.harness/tasks.json`
- `.harness/progress.txt`
- `.harness/active`
- `.harness/reflect`
- `.harness/stop-counter`
- `.harness/init.sh`
- `.harness/tasks.json.bak`
- `.harness/tasks.json.tmp`

During the init phase, if the project is a git repo and `.gitignore` already exists, ensure `.harness/` is present there.

## Notes

- `harness-claim.py` and `harness-renew.py` are helper scripts for future worker integration; they are not auto-registered as Claude hooks.
- `TeammateIdle` and `SubagentStop` hooks matter only when you are using Claude's teammate/subagent features; they are harmless otherwise.
- If you also install other `Stop` hooks, keep the harness hooks as a contiguous block so `harness-stop.py` and `self-reflect-stop.py` stay in order.
