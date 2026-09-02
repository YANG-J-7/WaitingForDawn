# Waiting for Dawn 项目协作规则

## 语言

- 项目交流、代码注释和文档使用中文。

## 开发进度维护（强制）

- 每次开始设计、开发、修复或测试前，必须完整阅读根目录 `DEVELOPMENT_PROGRESS.md` 和 `production/project-state.yaml`。
- 根据任务读取对应的 `design/gdd/` 文档和 `production/stories/` Story，不得以旧聊天记录替代仓库事实。
- 开始修改前执行 `git status -sb`，保护用户已有和未提交的改动。
- 每次开发结束后必须更新 `DEVELOPMENT_PROGRESS.md`：至少更新日期、当前进度、验证结果、已知问题、下一步和变更日志。
- 若阶段、当前目标或活动 Story 改变，必须同步更新 `production/project-state.yaml`。
- Story 实现或验收状态改变时，必须同步更新对应 Story 的状态和验证证据。
- 未运行验证时不得声称功能完成；完成前至少执行相关测试、`tools/check_project.ps1` 和 `git diff --check`。

## 项目权威规则

- 最终局制以 `design/gdd/single-night-wave-system.md` 为准：单关、单夜、十波。
- Godot 主场景为 `res://src/main/main.tscn`，当前开发版本为 Godot 4.7 Standard。
- `.godot/`、`.codex-temp/`、构建产物和本地凭据不得提交。
