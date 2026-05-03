# PR Review Reply

## 怎么来的

用 CodeRabbit 和 Gemini Code Assistant 来自动审查代码，质量还不错，但问题也挺多的。

一是它们会吐出一堆噪音——什么风格建议、个人偏好之类的，跟代码质量没太大关系。二是 CodeRabbit 审查慢，每次都要等 2~5 分钟。最烦的是，只要 push 一下代码，它就会重新审查一遍，之前的工作全白费，审查轮数一堆一堆的，时间全浪费了。还有就是它会限流，限流的时候就干脆没有审查结果了。

所以这个东西就是来解决这个问题的：自动聚合所有审查反馈，自己判断真假、决定改还是反驳、在线程里回复、标记解决，最后一次性 push——这样就不会中间多次 push 一直重复触发 CodeRabbit，而且限流的时候还能自动降级用 Codex 顶替审查。

## 流程

整个过程是这样的：

```
   ┌─────────────────────────────────────────────────────────────┐
   │  Step 1: 获取审查信号                                         │
   │  - Review bodies (HTML 块中的 findings)                      │
   │  - Line-level comments (有 thread ID)                       │
   │  - CI 状态                                                   │
   └────────────────┬────────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────────┐
        │ 等待所有 Bot 完成审查?     │
        │ (CodeRabbit + Gemini)      │
        └───────┬─────────┬─────────┘
                │         │
        State B: Pending  State A, C, D: Terminal
                │         │
                ▼         ▼
        重试      ┌─────────────────────┐
        (等待)   │  Step 2: 验证 Finding │
                │ 逐一对照代码和 CI    │
                └────────────┬─────────┘
                             │
                             ▼
                ┌───────────────────────────┐
                │ 状态检查:                   │
                │ A. 审查完成 ──→ 继续       │
                │ B. 审查中    ──→ 等待      │
                │ C. 限流      ──→ 用 Codex │
                │ D. 无 findings ──→ 完成    │
                └────────┬──────────────────┘
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
        ┌────────────┐      ┌──────────────┐
        │ 状态 A/C:  │      │ 状态 B:      │
        │ 有 Finding │      │ 轮询重试     │
        │            │      │              │
        │ ↓          │      │ ↓            │
        │ Step 3:    │      │ 返回并稍后   │
        │ Fix/Rebut  │      │ 重新运行     │
        │            │      └──────────────┘
        └────┬───────┘
             │
             ▼
        ┌─────────────────────────┐
        │ Step 4: 在线程下回复     │
        │ - 若有 comment ID 则回复 │
        │ - 无则发起新讨论        │
        └────────────┬────────────┘
                     │
                     ▼
        ┌─────────────────────────┐
        │ Step 5: 解决 Review 线程 │
        │ (resolve 只能用 GraphQL) │
        └────────────┬────────────┘
                     │
                     ▼
        ┌─────────────────────────┐
        │ All Findings Done?       │
        └───────┬─────────┬────────┘
                │         │
        No      │         │  Yes
                ▼         ▼
            ┌────────┐  ┌──────────┐
            │ Loop   │  │ Step 6:  │
            │ Again  │  │ Push 并   │
            └────────┘  │ 重新审查  │
                        └──────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Max 3 轮?       │
                    └────┬────────┬──┘
                         │        │
                     是  │        │  否
                        ▼        ▼
                    ┌────────┐  返回 Step 1
                    │ 完成   │
                    │ 输出   │
                    │ 总结   │
                    └────────┘
```

## 几个要点

### 1. 审查反馈来自两个地方

line-level comments（逐行评论，带 thread ID）容易看到，但反馈还藏在 review body 里。CodeRabbit 喜欢用 HTML 的 `<details>` 块来整理"🧹 Nitpicks"、"⚠️ Potential Issues"这种，每一条都是独立的问题，即使没有对应的逐行评论也要处理。不然就会漏掉一堆东西。

这里有个坑：CodeRabbit 有时候**只**把 findings 放 review body 的 `<details>` 块里，一个 line-level comment 都不发。表面看像"无 findings"，实际上全是 findings。不把这种情况当 State A 处理就会直接跳过一堆问题。

### 2. 得等审查机器人审完了才能处理

一个 PR 可能同时有 CodeRabbit 和 Gemini 在审。千万不能其中一个还在审的时候就开始 push 代码，那样之前的等待就白费了，还会重新触发还在审的那个机器人。得全部都完成了（或限流了、或啥都没有了），才能一起处理。

### 3. CodeRabbit 的脾气

CodeRabbit 是这里面最耗时间的：

- 审查得 2~5 分钟，大 PR 可能更久
- 每次 `git push` 它都得重新来一遍，之前的行评注可能就失效或被替换了
- 限流了就没办法审查，只会留个"limit exceeded"的评论

所以工作流就得严格一点：**处理完所有问题之前坚决不 push**。所有的改动都先在本地攒着，等所有问题都 fix 了或 rebut 了，都回复了，都标记解决了，最后才一次性 push。

如果全部都是 rebut、零代码改动，但还需要触发 bot 重新审查，就用空 commit push：`git commit --allow-empty -m "chore: trigger re-review"`。

### 4. 限流的时候用备选方案

CodeRabbit 限流了就没招了吗？不是。这时候就自动切到 Codex：

```bash
code-dispatcher --backend codex "Review the PR diff and identify real issues. Ignore style nitpicks."
```

用 Codex 的结果继续 fix/rebut，过程都是一样的。

### 5. 用代码和测试结果说话

每个反馈都得对照一下。不能光看机器人怎么说，得自己看：

- 本地代码和对应的那几行是啥样
- CI 输出怎么样
- 现有的测试是什么

代码和 CI 能说明这个反馈是错的、不适用，就明确 rebut；是真实问题，就 fix。

回复用的是三段式结构：**Decision + Reason + Verification**。这个结构不是给自己看的，是给 reviewer bot 下一轮审查时当上下文的——结构化输出让 bot 能快速判断这条 finding 已处理，避免重复报告。

### 6. 最多处理 3 轮

为了不陷入无限循环，最多就是"处理反馈 → 等审查 → 处理新反馈"这样循环 3 次。第 3 轮以后就不处理了，输出最终总结。

### 7. Resolve Review 线程只能走 GraphQL

这是个坑。GitHub REST API 可以回复 review comment，但不能标记 review thread 已解决。所以 resolve 这步必须用 GraphQL mutation，thread ID 也得从 GraphQL 查询里拿。

## 规则

- 每个 finding 必须先回复再 resolve
- 禁止无声 resolve（没回复就标记解决）
- 有线程就回线程，不另开 top-level comment
- review body 里的 finding 没有对应线程时，才发 scoped PR comment
- reviewer 的严重级别标签只是参考，代码和 CI 证据才是最终裁决

## 自动化

这个技能就是一个完全自动化的流程。触发以后就从 Step 1 一直跑到 Step 6，中间不会问该继续吗、怎么处理之类的。所有的 fix 还是 rebut 的决策都是代码和 CI 测试来做主，所有的回复和线程标记解决都自动进行。只有少数几种情况需要人工介入（比如当前分支不对、有未提交改动、要大规模改架构这样的），其他都自己搞定。
