#!/usr/bin/env bash
# Review Loop — Stop Hook
#
# Two-phase lifecycle:
#   Phase 1 (task):       Claude finishes work → hook runs code-dispatcher parallel review → blocks exit
#   Phase 2 (addressing): Claude addresses review → hook allows exit
#
# On any error, default to allowing exit (never trap the user in a broken loop).

LOG_FILE=".claude/review-loop.log"

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE"
}

trap 'log "ERROR: hook exited via ERR trap (line $LINENO)"; printf "{\"decision\":\"approve\"}\n"; exit 0' ERR

# Consume stdin (hook input JSON) — must read to avoid broken pipe
HOOK_INPUT=$(cat)

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}" ]; then
  cd "${CLAUDE_PROJECT_DIR}" 2>/dev/null || true
fi

STATE_FILE=".claude/review-loop.local.md"

# No active loop → allow exit
if [ ! -f "$STATE_FILE" ]; then
  printf '{"decision":"approve"}\n'
  exit 0
fi

# Parse a field from the YAML frontmatter
parse_field() {
  sed -n "s/^${1}: *//p" "$STATE_FILE" | head -1
}

ACTIVE=$(parse_field "active")
PHASE=$(parse_field "phase")
REVIEW_ID=$(parse_field "review_id")

# Not active → clean up and exit
if [ "$ACTIVE" != "true" ]; then
  rm -f "$STATE_FILE"
  printf '{"decision":"approve"}\n'
  exit 0
fi

# Validate review_id format to prevent path traversal
if ! echo "$REVIEW_ID" | grep -qE '^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$'; then
  log "ERROR: invalid review_id format: $REVIEW_ID"
  rm -f "$STATE_FILE"
  printf '{"decision":"approve"}\n'
  exit 0
fi

# Safety: if stop_hook_active is true and we're still in "task" phase,
# something went wrong with the phase transition. Allow exit to prevent loops.
STOP_HOOK_ACTIVE=false
if echo "$HOOK_INPUT" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' 2>/dev/null; then
  STOP_HOOK_ACTIVE=true
fi
if [ "$STOP_HOOK_ACTIVE" = "true" ] && [ "$PHASE" = "task" ]; then
  log "WARN: stop_hook_active=true in task phase, aborting to prevent loop"
  rm -f "$STATE_FILE"
  printf '{"decision":"approve"}\n'
  exit 0
fi

# Emit a one-time block message, then allow user to stop again to exit.
block_once_and_clear_state() {
  local reason="$1"
  rm -f "$STATE_FILE"
  printf '{"decision":"block","reason":"%s"}\n' "$reason"
}

case "$PHASE" in
  task)
    mkdir -p .claude reviews

    DIFF_FILE="reviews/review-${REVIEW_ID}-diff.md"
    HOLISTIC_FILE="reviews/review-${REVIEW_ID}-holistic.md"
    REVIEW_FILE="reviews/review-${REVIEW_ID}.md"
    DISPATCHER_LOG=".claude/review-loop.dispatcher-${REVIEW_ID}.log"

    DISPATCHER_BIN="$(command -v code-dispatcher 2>/dev/null || command -v code-dispatcher.exe 2>/dev/null || true)"
    if [ -z "$DISPATCHER_BIN" ]; then
      log "ERROR: code-dispatcher not found on PATH"
      block_once_and_clear_state "ERROR: code-dispatcher not found on PATH. Install code-dispatcher, then rerun /review-loop."
      exit 0
    fi

    START_TIME=$(date +%s)
    DISPATCHER_EXIT=0

    log "Starting code-dispatcher parallel review (review_id=$REVIEW_ID)"

    "$DISPATCHER_BIN" --parallel --backend codex >"$DISPATCHER_LOG" 2>&1 <<EOF || DISPATCHER_EXIT=$?
---TASK---
id: diff-review
workdir: .
---CONTENT---
You are an independent code reviewer.

Task:
1) Run: git diff, git diff --cached, git log --oneline -5, git diff HEAD~5
2) Review ONLY the changed code: correctness, tests, security.
3) Write a markdown report to: ${DIFF_FILE}

Rules:
- Do NOT modify any source code.
- Be specific: severity (critical/high/medium/low), file:line, description, suggested fix.

---TASK---
id: holistic-review
workdir: .
---CONTENT---
You are an independent code reviewer.

Task:
1) Review overall project structure, architecture, documentation, and maintainability.
2) Write a markdown report to: ${HOLISTIC_FILE}

Rules:
- Do NOT modify any source code.
- Be specific and actionable.
EOF

    ELAPSED=$(( $(date +%s) - START_TIME ))
    log "code-dispatcher finished (exit=$DISPATCHER_EXIT, elapsed=${ELAPSED}s, log=$DISPATCHER_LOG)"

    if [ "$DISPATCHER_EXIT" -ne 0 ]; then
      block_once_and_clear_state "ERROR: review generation failed. Check .claude/review-loop.dispatcher-${REVIEW_ID}.log, then rerun /review-loop."
      exit 0
    fi

    if [ ! -f "$DIFF_FILE" ] || [ ! -f "$HOLISTIC_FILE" ]; then
      log "ERROR: expected review files missing (diff=$DIFF_FILE, holistic=$HOLISTIC_FILE)"
      block_once_and_clear_state "ERROR: review files not created. Check .claude/review-loop.dispatcher-${REVIEW_ID}.log, then rerun /review-loop."
      exit 0
    fi

    # Concatenate (no dedup) into a single file Claude can read.
    {
      printf "# Review Loop %s\n\n" "$REVIEW_ID"
      printf "## Diff Review\n\n"
      cat "$DIFF_FILE"
      printf "\n\n## Holistic Review\n\n"
      cat "$HOLISTIC_FILE"
      printf "\n"
    } > "$REVIEW_FILE"

    if [ ! -f "$REVIEW_FILE" ]; then
      log "ERROR: failed to assemble review file: $REVIEW_FILE"
      block_once_and_clear_state "ERROR: failed to assemble review file. Rerun /review-loop."
      exit 0
    fi

    # Transition to addressing phase
    if [ "$(uname)" = "Darwin" ]; then
      sed -i '' 's/^phase: task$/phase: addressing/' "$STATE_FILE"
    else
      sed -i 's/^phase: task$/phase: addressing/' "$STATE_FILE"
    fi

    REASON="Review written to ${REVIEW_FILE}. Read it, address findings, then stop again."
    SYS_MSG="Review Loop [${REVIEW_ID}] — Phase 2/2: Address feedback"
    printf '{"decision":"block","reason":"%s","systemMessage":"%s"}\n' "$REASON" "$SYS_MSG"
    ;;

  addressing)
    log "Review loop complete (review_id=$REVIEW_ID)"
    rm -f "$STATE_FILE"
    printf '{"decision":"approve"}\n'
    ;;

  *)
    log "WARN: unknown phase '$PHASE', cleaning up"
    rm -f "$STATE_FILE"
    printf '{"decision":"approve"}\n'
    ;;
esac
