# Review Loop 模板（code-dispatcher 版）

可复制粘贴的 Claude Code review-loop 模板：
- `/review-loop <任务>` 让 Claude 先实现任务
- Claude `stop` 时，Stop hook 调用 `code-dispatcher --parallel` 跑两个独立 reviewer：
  - Diff Review（只看改动）
  - Holistic Review（看整体结构/可维护性）
- 生成 review 后 Claude 继续处理，再次 stop 才退出

## 模板内容

- `settings.json`：注册 Stop hook
- `hooks/review-loop-stop.sh`：Stop hook 脚本
- `commands/review-loop.md`：启动 review loop
- `commands/cancel-review.md`：取消 review loop

## 安装

将本目录下的 `commands/`、`hooks/` 复制到你项目的 `.claude/` 目录下：

```bash
cp -r commands/ <your-project>/.claude/commands/
cp -r hooks/    <your-project>/.claude/hooks/
chmod +x <your-project>/.claude/hooks/review-loop-stop.sh
```

然后把 `settings.json` 中的 `hooks.Stop` 合并到你项目的 `.claude/settings.json`（团队共享）或 `.claude/settings.local.json`（个人本地）。

安装后项目结构：
```text
<your-project>/.claude/
├── commands/
│   ├── review-loop.md
│   └── cancel-review.md
├── hooks/
│   └── review-loop-stop.sh
└── settings.json (或 settings.local.json)
```

## 依赖
- `code-dispatcher` 在 PATH 中
- `codex` CLI 在 PATH 中（`npm install -g @openai/codex`）

Windows：Claude Code 通常依赖 Git Bash，请确保 Git Bash 的 PATH 也包含 `~/.code-dispatcher/bin`。

## 使用

启动 loop：
```text
/review-loop Implement feature X with tests
```

取消：
```text
/cancel-review
```

## 产物
- 状态文件：`.claude/review-loop.local.md`
- reviewer 输出：
  - `reviews/review-<id>-diff.md`
  - `reviews/review-<id>-holistic.md`
- 合并文件（无去重）：`reviews/review-<id>.md`
- 日志：
  - `.claude/review-loop.log`
  - `.claude/review-loop.dispatcher-<id>.log`

建议将 `reviews/` 加入项目 `.gitignore`，避免 review 产物混入提交。
