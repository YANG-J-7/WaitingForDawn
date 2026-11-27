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

- 2026-11-26开局方向：正式第一关开局从手牌拖放一级守夜厅，合法落位后准备10秒，归零启动怪物进攻及60分钟对局。商店免费领取3张建筑卡，至少含1张伤害牌，未领名额进入战斗后继续有效。主城外观选定红瓦方案，二至五级的升级条件待定。
- 2026-09-16新版方向：Steam单机，一局60分钟且每局从零开始；主城存活至60:00即胜利，同帧主城被摧毁优先判负。初始人口5/5，木材、食物、石材、铁矿各100，金币0。通过击杀野怪赚金币，用于六格商店买牌与刷新。3张同名同星手牌手动合成高一星卡，已建建筑不参与，首个原型最高3星。普通建筑可在地图无单位位置自由放置，特定建筑要求特定位置；制作大地图并加入地形与天气。当前规则见 `design/gdd/sixty-minute-campaign-system.md` 与 `design/gdd/kill-gold-card-shop-fusion-system.md`，尚待确定的逐卡星级、地形与天气细则不得作为已批准内容。
- `design/gdd/single-night-wave-system.md` 保留十波灰盒的历史规则。现用十份威胁模板循环，正式局制由60分钟计时和主城存活结算。
- Godot 主场景为 `res://src/main/main.tscn`，当前开发版本为 Godot 4.7 Standard。
- `.godot/`、`.codex-temp/`、构建产物和本地凭据不得提交。
