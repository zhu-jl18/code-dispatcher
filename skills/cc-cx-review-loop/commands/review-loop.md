---
description: "Start a review loop: implement task, run independent review via code-dispatcher, address feedback"
argument-hint: "<task description>"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

First, set up the review loop by running this setup command:

```bash
set -e && REVIEW_ID="$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 3 2>/dev/null || head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')" && mkdir -p .claude reviews && if [ -f .claude/review-loop.local.md ]; then echo "Error: A review loop is already active. Use /cancel-review first." && exit 1; fi && (command -v code-dispatcher >/dev/null 2>&1 || command -v code-dispatcher.exe >/dev/null 2>&1) || { echo "Error: code-dispatcher not found on PATH. Install it from zhu-jl18/code-dispatcher-toolkit and ensure ~/.code-dispatcher/bin is on PATH."; exit 1; } && command -v codex >/dev/null 2>&1 || { echo "Error: Codex CLI is not installed. Install it: npm install -g @openai/codex"; exit 1; } && cat > .claude/review-loop.local.md << STATE_EOF
---
active: true
phase: task
review_id: ${REVIEW_ID}
started_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
---

$ARGUMENTS
STATE_EOF
echo "Review Loop activated (ID: ${REVIEW_ID})"
```

After setup completes successfully, proceed to implement the task described in the arguments. Work thoroughly and completely — write clean, well-structured, well-tested code.

When you believe the task is fully done, stop. The review loop stop hook will automatically:
1. Run an independent parallel review via code-dispatcher (Diff + Holistic)
2. Present the review for you to address

RULES:
- Complete the task to the best of your ability before stopping
- Do not stop prematurely or skip parts of the task
- The review loop handles the rest automatically
