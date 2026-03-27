# Skills and Bundles Guide (Overview)

This document summarizes available Skills and Bundles in the `code-dispatcher` toolkit.


## Skills List

### `code-dispatcher`

Provides detailed instructions for the code-dispatcher executor, supporting unified scheduling across three backends: codex, claude, and gemini, with `--parallel` parallel execution and `--resume` checkpoint recovery capabilities. This Skill is the foundation for most other Skills.

```text
┌─────────────────────────────────────────────────────────────────┐
│                     code-dispatcher Architecture                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   User Request ──→ ┌─────────────┐ ──→ ┌─────────┐ ──→ Results   │
│                    │  Backend    │     │ Codex   │                  │
│                    │  Router     │     │ Claude  │                  │
│                    │             │     │ Gemini  │                  │
│                    └─────────────┘     └─────────┘                  │
│                           │                                         │
│           ┌───────────────┼───────────────┐                             │
│           ▼               ▼               ▼                             │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐                      │
│   │ Task A   │  │ Task B   │  │ Task C   │   ← --parallel       │
│   │ backend  │  │ backend  │  │ backend  │      DAG Scheduling   │
│   │ :codex   │  │ :claude  │  │ :gemini  │                      │
│   └──────────┘  └──────────┘  └──────────┘                      │
│        │             │             │                            │
│        └─────────────┴─────────────┘                            │
│                      │                                          │
│                      ▼                                          │
│              ┌─────────────┐                                    │
│              │  Session ID │  ← --resume Recovery              │
│              └─────────────┘                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### `dev`

End-to-end development workflow orchestrator covering the complete feature implementation cycle. Workflow includes: requirements clarification, development planning, intelligent backend selection, DAG-based parallel task execution, and code coverage verification.

```text
┌─────────────────────────────────────────────────────────────────┐
│                      dev Workflow (7 Steps)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Step 0        Step 1        Step 2        Step 3             │
│   ┌───┐        ┌───┐         ┌───┐         ┌───┐               │
│   │Select│  →  │Reqs │  →    │Analyze│  →  │Plan │              │
│   │Backend│     │Clarify│     │Research│     │Create│             │
│   └───┘        └───┘         └───┘         └───┘               │
│                                               │                 │
│                                               ▼ (User Confirm)   │
│   Step 6        Step 5        Step 4        ┌───┐              │
│   ┌───┐        ┌───┐         ┌───┐         │Execute│              │
│   │Report│  ←  │Verify│  ←   │Parallel│ ←  │DAG │              │
│   │Summary│     │Coverage│    │Execute│     │Schedule│              │
│   └───┘        └───┘         └───┘         └───┘               │
│                                    code-dispatcher --parallel   │
│                                                                 │
│   Coverage Requirement: >= 90%                                  │
│   Failure Retry: Up to 2 rounds                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### `code-council`

Multi-backend parallel code review solution, simultaneously launching 2-3 independent AI reviewers for cross-verification, with the host agent performing final review and outputting a unified report.

```text
┌─────────────────────────────────────────────────────────────────┐
│                     code-council Review Flow                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Target Code ──┬──→ ┌──────────┐                                  │
│   @file        │    │ Reviewer │ ──┐                              │
│   diff         │    │  Codex   │   │                              │
│                │    └──────────┘   │                              │
│                │                   │                              │
│                ├──→ ┌──────────┐   │    ┌──────────────┐          │
│                │    │ Reviewer │   ├──→ │ Host Agent   │          │
│                │    │  Claude  │   │    │              │          │
│                │    └──────────┘   │    │ 1. Deduplicate│          │
│                │                   │    │ 2. Validate   │          │
│                ├──→ ┌──────────┐   │    │ 3. Score      │          │
│                     │ Reviewer │   │    │ 4. Synthesize │          │
│                     │  Gemini  │ ──┘    └──────────────┘          │
│                     └──────────┘            │                     │
│                                             ▼                     │
│                              ┌─────────────────────┐           │
│                              │ Code Council Report │           │
│                              │ - CRITICAL          │           │
│                              │ - WARNING           │           │
│                              │ - INFO              │           │
│                              └─────────────────────┘           │
│                                                                 │
│   Confidence Rules: ≥2 reviewers report → High Confidence       │
│                     Only 1 report → Host verification needed    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### `github-issue-pr-flow`

Complete Issue-to-PR closed-loop delivery workflow, automatically completing requirement decomposition, code implementation, PR submission, code review handling, and final squash-merge.

```text
┌─────────────────────────────────────────────────────────────────┐
│                    github-issue-pr-flow Process                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Phase 0      Phase 1       Phase 2       Phase 3              │
│   ┌───┐       ┌───┐        ┌───┐        ┌───┐                 │
│   │Sync│  →   │Decompose│→ │Implement│→ │Open PR│                │
│   │Baseline│    │Issue  │     │Branch  │    │Link│                │
│   └───┘       └───┘        └───┘        └───┘                 │
│     │                                          │                │
│     │    Phase 6      Phase 5       Phase 4    │                │
│     │    ┌───┐       ┌───┐        ┌───┐       │                │
│     └──→ │Merge│ ←   │Handle│ ←   │Gather│ ←─────┘                │
│          │Close│       │Review│       │Signals│                      │
│          └───┘       └───┘        └───┘                      │
│            │                                            │      │
│            └────────────────────────────────────────────┘      │
│                          Loop (max 3 rounds)                     │
│                                                                 │
│   squash-merge → delete remote branch → verify issue closed     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### `pr-review-reply`

Specialized workflow for processing automated bot reviews (e.g., Gemini, CodeRabbit). Automatically reads review comments, validates each finding, decides to fix or rebut, and replies/resolves in the corresponding GitHub review thread.

```text
┌─────────────────────────────────────────────────────────────────┐
│                    pr-review-reply Process                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Step 1: Get Comments                                           │
│   ┌──────────────────────────────────────────┐                 │
│   │  Source 1: Review body (<details> blocks) │                 │
│   │  Source 2: Line-level comment threads     │                 │
│   │  Source 3: CI status                      │                 │
│   └──────────────────────────────────────────┘                 │
│                      │                                          │
│                      ▼                                          │
│   Step 2: Validate Code ──→ Read Files ──→ Check CI ──→ Cross-validate│
│                      │                                          │
│                      ▼                                          │
│   Step 3: Decision  ┌─────────┐    ┌─────────┐                 │
│                     │  Fix    │ or │ Rebut   │                 │
│                     │         │    │         │                 │
│                     └────┬────┘    └────┬────┘                 │
│                          │              │                      │
│                          ▼              ▼                      │
│   Step 4: Local      Modify Code    Gather Evidence             │
│           (no push)    │           Draft Reply                  │
│                        │                                      │
│                        └──────────┬───────────────────────────┘
│                                   │
│                                   ▼
│   Step 5: Reply Thread ←── gh api reply comment                 │
│                                   │
│                                   ▼
│   Step 6: Resolve Thread ←── GraphQL resolveReviewThread       │
│                                   │
│           All processed ──→ batch push ──→ wait for re-review  │
│                                                                 │
│   Loop Limit: max 3 rounds                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```


## Bundles List

This repo no longer maintains these two bundles directly. They have moved to `fish-claude`:

- `harness`: [fish-claude/packs/harness](../../fish-claude/packs/harness)
- `codex-review-loop`: [fish-claude/packs/codex-review-loop](../../fish-claude/packs/codex-review-loop)
