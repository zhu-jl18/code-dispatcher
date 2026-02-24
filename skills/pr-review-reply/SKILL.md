---
name: pr-review-reply
description: "Autonomous PR bot-review triage skill for Gemini, CodeRabbit, and similar reviewers. Detects the current PR, validates each finding against code and CI, decides fix-or-rebut, replies in the matching GitHub review thread, and resolves handled threads. Use when the user asks to triage, respond to, or clear bot review comments on a PR."
---

# PR Review Reply

## Purpose
Autonomously handle all bot review findings on the current PR end-to-end:
fetch → verify → fix or rebut → reply under thread → resolve thread.

## Autonomy Directive
This skill is a **fully autonomous pipeline**. Once invoked, execute Step 1 through Step 6 without pausing for user confirmation between steps.
- Do NOT stop to ask the user "should I continue?" or "what do you think?" at any intermediate point.
- Do NOT present findings to the user and wait for instructions — you decide fix or rebut based on code evidence.
- Do NOT summarize partial progress and then stop — finish the entire workflow first, then give one final summary.
- The ONLY situations where you may stop mid-workflow are listed in the Escalation section. Everything else: handle it yourself and keep going.

## Context Detection
```bash
export GH_PAGER=cat
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR=$(gh pr view --json number -q .number)
```

## Workflow

### Step 1: Fetch Review Signals
Collect **both** signal sources — you must check both every time, including on re-review loops:

**Source 1: Review bodies** (findings may live ONLY here, with no line-level comment)
```bash
gh pr view $PR --json reviews \
  --jq '[.reviews[] | {author: .author.login, state: .state, body: .body}]'
```
CodeRabbit often embeds findings inside the review body as `<details>` / `<summary>` HTML blocks (e.g. "🧹 Nitpick comments", "⚠️ Potential issues"). Parse these blocks — each one is a distinct finding that needs fix or rebut, even if there is no corresponding line-level comment thread.

**Source 2: Line-level comment threads** (with IDs for reply/resolve)
```bash
gh api repos/$REPO/pulls/$PR/comments --paginate \
  --jq '[.[] | {id: .id, author: .user.login, path: .path, line: (.line // .original_line), body: .body, in_reply_to: .in_reply_to_id}]'
```

**Source 3: CI status**
```bash
gh pr checks $PR
```

Filter for bot authors: `gemini-code-assist`, `coderabbitai`.
Skip only threads that are already resolved, or have an explicit maintainer reply that fully addresses the finding.

**Findings = union of Source 1 + Source 2.** A finding from Source 1 that has no matching Source 2 thread is still a real finding — handle it via a scoped PR comment reply (Step 4 fallback).

#### Wait for ALL Bots Before Acting
Multiple bots may review the same PR (e.g. CodeRabbit + Gemini). Do NOT start fixing/rebutting until **all** expected bot reviews have landed.
- Check which bots have posted reviews and which are still pending.
- If CodeRabbit is pending but Gemini is done (or vice versa): **wait for the slow one**. Do not push fixes based on only one bot's review — the push will re-trigger CodeRabbit and you'll waste the wait.
- Once all bots reach a terminal state (State A/C/D), collect all findings from all bots into one unified list, then proceed to Step 2.

#### CodeRabbit Behavior Model
CodeRabbit is **slow**. You must internalize these facts:
- A full review takes 2–5 minutes, sometimes longer for large PRs.
- Every `git push` to the PR branch **re-triggers** a new review from scratch. The old review's line comments may become outdated or get replaced.
- CodeRabbit has API rate limits. When hit, it posts a comment like "rate limit exceeded" or simply never completes its review.
- A review in progress shows as `PENDING` state, or the bot posts a summary-only comment (e.g. "Walkthrough") with zero line-level findings yet.

You cannot rush this. Plan your workflow around it.

#### Pending vs Rate-Limited vs Done
After fetching signals, classify the bot review state:

**State A — Review complete (terminal):**
Bot review state is `COMMENTED` / `APPROVED` / `CHANGES_REQUESTED` / `DISMISSED`, AND line-level comments exist (or the body is a full summary with zero line comments = no findings). → Proceed to Step 2.

**State B — Review still running (pending):**
Any of these signals:
- Review `state` is `PENDING`
- Review body is empty / placeholder / progress indicator only
- Bot posted a summary ("Walkthrough") but has zero line-level comments and the review was created < 10 min ago
- No bot review exists at all but the PR was pushed < 10 min ago

Action: CodeRabbit typically finishes within ~5 minutes. Wait and re-check until the review lands. You decide the wait intervals and retry count — just don't give up too early (< 3 min) or wait forever (> 10 min total). If it's still pending after your patience runs out, exit with a one-line message and let the user re-run later.

**State C — Rate limited:**
Detection: bot posted a comment or review body containing "rate limit", "API rate", "quota exceeded", or similar. Or: bot review is absent and PR was pushed > 15 min ago (bot should have responded by now).

Action: CodeRabbit is unusable. Fall back to Codex for review:
```bash
code-dispatcher --backend codex "Review the PR diff and identify real issues. Ignore style nitpicks."
```
Then continue the fix/rebut workflow using Codex's findings instead of CodeRabbit's. The goal is the same: fix real issues, rebut false positives.

**State D — Legit zero findings:**
Bot review is in terminal state AND:
- Zero line-level comments, AND
- Review body contains no `<details>` / nitpick / issue blocks (just a walkthrough summary or "no issues found")

Only then: print "CodeRabbit: no findings" and exit cleanly. Do NOT poll.
**If the review body contains `<details>` blocks with findings but zero line-level comments, this is NOT State D — it's State A with body-only findings. Process them.**

Get unresolved thread IDs via GraphQL (needed for resolving):
```bash
# Parse owner/repo from $REPO (e.g., "owner/repo" → owner="owner", name="repo")
OWNER="${REPO%/*}"
NAME="${REPO#*/}"

gh api graphql -f query='
query($owner: String!, $name: String!, $pr: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes { id isResolved comments(first: 1) { nodes { databaseId author { login } body } } }
      }
    }
  }
}' -F owner="$OWNER" -F name="$NAME" -F pr="$PR"
```

### Step 2: Verify Each Finding
For every unresolved bot finding, before deciding fix or rebut:
- Read the referenced file and line(s) from the local repo
- Check if the concern is reproducible or observable in the current code
- Cross-check with existing tests and CI output

Do not accept or reject a finding based on reviewer wording alone — code evidence is the deciding factor.

### Step 3: Fix or Rebut
See `references/triage-guide.md` for decision criteria and reply templates.

**Critical: do NOT commit or push until you've processed ALL findings from ALL bots.** A premature push re-triggers CodeRabbit and wastes minutes of wait time. Accumulate all code changes locally first.

**Fix path:**
1. Make code change locally — do NOT commit yet
2. Continue to next finding

**Rebut path:**
1. Collect concrete evidence (file path, line, test result, invariant)
2. Draft reply with evidence

### Step 4: Reply Under Thread
Reply under the exact comment that raised the finding whenever a replyable thread exists:

```bash
gh api repos/$REPO/pulls/$PR/comments \
  -f body="<reply text>" \
  -F in_reply_to=<comment_id>
```

The root comment ID of a thread is the one **without** `in_reply_to_id`.
If a review-level finding has no replyable thread/comment ID, post one scoped PR comment that references reviewer identity and finding context.

### Step 5: Resolve Thread
After replying, resolve the thread via GraphQL using the thread node ID from Step 1:

```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) {
    thread { isResolved }
  }
}' -F threadId="<thread_node_id>"
```

### Step 6: Push and Wait for Re-review
You should only reach this step after ALL findings from ALL bots have been processed (fix or rebut + reply + resolve).

If you made code changes:
1. Commit and push all fixes in **one single batch**. Never push per-finding — every push re-triggers CodeRabbit and wastes 5+ min.
2. After push, go back to Step 1. **Re-fetch BOTH review bodies AND line-level comments from scratch.** Compare the new review body against the previous round's body to detect new findings — do not assume "same review count = no changes".
3. If new findings appear (in either source) → process them (Step 2–5). If no new findings → done.

If no code changes were made (all rebuttals), skip the push. No re-review needed.

Use an empty commit only when a new bot pass is explicitly required and no code change commit exists:
```bash
git commit --allow-empty -m "chore: trigger re-review" && git push
```

## Loop Limit
Max 3 rounds of fix/rebut → wait for re-review → process new findings. After round 3, stop and give final summary of any remaining unresolved items.

## Escalation
These are the ONLY situations where you may stop mid-workflow and ask the user:
- Current branch does not match PR head branch (do not auto-checkout)
- Unrelated uncommitted changes exist (do not auto-stash)
- A finding requires substantial architectural rework (> ~50 lines across multiple files)

Everything else — including CI failures, permission errors, missing files — handle inline (skip, note, retry) and keep going. Report all skipped/failed items in the final summary.

## Hard Rules
- Every handled finding **must** have a reply in its thread before resolving
- Never resolve a thread without replying — silent resolves are not allowed
- Never open a brand-new top-level PR comment when a replyable review thread exists
- Review-level (no-line) findings with no replyable thread: post one scoped PR comment instead of forcing an invalid thread reply
- Treat reviewer severity labels as hints, not final decisions; code and CI evidence decide outcomes

## Error Handling

### Pending / Empty Review State
If you reach Step 2 with an empty finding list:
- Re-read Step 1's state classification (A/B/C/D) — you likely skipped the pending check
- Never conclude "nothing to do" without confirming State A or State D
- `PENDING` is NOT a terminal state — go back and wait
- If the bot seems dead (> 15 min, no response), classify as State C and fall back to codex

### Local Repo State Checks
Before making changes:
- Verify current branch matches PR head branch: `gh pr view $PR --json headRefName -q .headRefName`
- If on wrong branch: **stop** (this is an allowed escalation point)
- If unrelated uncommitted changes exist: **stop** (this is an allowed escalation point)

### Missing File in Finding
If a bot comment references a file that doesn't exist locally:
- Check PR diff: `gh pr diff $PR --name-only`
- If file was deleted/renamed in PR: skip the finding, reply noting file no longer exists, **then continue**
- If file never existed: rebut with file listing evidence, **then continue**

### Comment Without Line Number
Some bot comments may lack line context:
- Use PR diff to locate relevant code: `gh pr diff $PR -- <path>`
- If still unclear: reply in-thread when possible; otherwise post one scoped PR comment. **Then continue** — do not resolve unclear threads but do not stop the workflow either.

### Thread Resolution Fails
If GraphQL mutation to resolve thread fails:
- Check if thread was already resolved by someone else
- If permission issue: skip resolution, note in final summary, **continue**
- If ID invalid: re-fetch thread IDs and retry once. If still fails, skip and **continue**
