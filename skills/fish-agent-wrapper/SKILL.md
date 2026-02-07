---
name: fish-agent-wrapper
description: Execute fish-agent-wrapper for multi-backend AI coding tasks. Supports Codex, Claude, Gemini, Ampcode with file references (@syntax), resume, and parallel execution.
---

# fish-agent-wrapper Integration

## Overview

Execute `fish-agent-wrapper` with pluggable backends (`codex`, `claude`, `gemini`, `ampcode`).

Core capabilities:
- Single task execution with backend selection
- Resume by `SESSION_ID`
- Parallel DAG execution via `--parallel`
- Per-backend prompt injection files

## Backend Strategy

| Backend | Command | Default Strength |
|---------|---------|------------------|
| codex | `--backend codex` | Deep code analysis and complex implementation (default) |
| claude | `--backend claude` | Quick fixes, docs, prompt-heavy tasks |
| gemini | `--backend gemini` | UI/UX and frontend implementation |
| ampcode | `--backend ampcode` | Plan review, code review, and hard bug fallback |

`ampcode` policy:
- Default mode is `smart`
- Recommended for reviewing `dev-plan.md`, PR-level code review, and retrying unresolved bugs
- Optional mode override: `FISH_AGENT_WRAPPER_AMPCODE_MODE=smart|deep|rush|free`

## Usage

**HEREDOC (recommended):**
```bash
fish-agent-wrapper --backend codex - [working_dir] <<'EOF'
<task content>
EOF
```

**Ampcode review example:**
```bash
fish-agent-wrapper --backend ampcode - . <<'EOF'
Review @.claude/specs/auth/dev-plan.md and provide:
1) critical risks
2) missing tests
3) simplification suggestions
EOF
```

**Simple task:**
```bash
fish-agent-wrapper --backend gemini "build responsive settings page" .
```

## Resume Session

```bash
fish-agent-wrapper --backend codex resume <session_id> - <<'EOF'
<follow-up>
EOF

fish-agent-wrapper --backend ampcode resume <session_id> - <<'EOF'
Continue review and focus on race conditions.
EOF
```

## Parallel Execution

```bash
fish-agent-wrapper --parallel <<'EOF'
---TASK---
id: analysis
backend: codex
workdir: .
---CONTENT---
Analyze architecture and define implementation checkpoints
---TASK---
id: impl
backend: claude
dependencies: analysis
workdir: .
---CONTENT---
Implement API layer and tests
---TASK---
id: review
backend: ampcode
dependencies: impl
workdir: .
---CONTENT---
Review diff quality, detect risky changes, propose fixes
EOF
```

## Parameters

- `task` (required): task text, supports `@file`
- `working_dir` (optional): working directory (default current dir)
- `--backend` (recommended): `codex | claude | gemini | ampcode` (default `codex`)

## Return Format

```
<assistant message>

---
SESSION_ID: <session-id>
```

## Environment Variables

- `CODEX_TIMEOUT`: timeout in milliseconds (default `7200000`)
- `FISH_AGENT_WRAPPER_SKIP_PERMISSIONS`: controls permission skipping behavior
- `FISH_AGENT_WRAPPER_MAX_PARALLEL_WORKERS`: limit parallel workers
- `FISH_AGENT_WRAPPER_CLAUDE_DIR`: base Claude config dir (default `~/.claude`)
- `FISH_AGENT_WRAPPER_AMPCODE_MODE`: ampcode mode override (`smart` default)

## Invocation Pattern

**Single task:**
```text
Bash tool parameters:
- command: fish-agent-wrapper --backend <backend> - [working_dir] <<'EOF'
  <task content>
  EOF
- timeout: 7200000
- description: <brief description>
```

**Parallel tasks:**
```text
Bash tool parameters:
- command: fish-agent-wrapper --parallel <<'EOF'
  ---TASK---
  id: <task-id>
  backend: <backend>
  workdir: <path>
  dependencies: <optional>
  ---CONTENT---
  <task content>
  EOF
- timeout: 7200000
- description: <brief description>
```

## Critical Rules

- Do not kill running `fish-agent-wrapper` processes unless required by timeout policy.
- For long tasks, inspect logs first, then decide retry.
- For unresolved bugs after normal implementation loops, add an `ampcode` review/retry task.

## Security Notes

- Automation-first execution can bypass interactive approvals depending on backend settings.
- In production CI, set explicit worker limits and timeout boundaries.
