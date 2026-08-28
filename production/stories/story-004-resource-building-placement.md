# Story-004：局内资源与生产建筑固定格位建造

> 状态：完成
> 创建：2026-08-28
> GDD：[单夜十波系统](../../design/gdd/single-night-wave-system.md)、[核心系统历史基线](../../design/gdd/core-loop-system.md)
> ADR：[Godot平台基线](../../docs/architecture/adr-0001-godot-platform-baseline.md)

## 用户故事

作为白天布防的玩家，我希望看见本局资源，并把已选的伐木场、农场或金矿场建到合法聚落格，同时清楚看到建造材料被扣除。

## 验收标准

1. 新对局初始化为140木材、32食物、60石材、30铁矿、20金币、6/8人口，资源栏持续显示当前值。
2. 免费选择卡牌不扣资源；只有成功确认建筑格位后才原子扣除建造成本。
3. 伐木场消耗35木材，农场消耗30木材与10石材，金矿场消耗50木材与10铁矿。
4. 白天显示3个聚落格；资源建筑只能建在空聚落格，每格最多1座。
5. 每张已选建筑卡只能成功建造1次；建成后锁定该卡，不能取消选择或重复使用。
6. 资源不足、卡牌未选择、卡牌类型错误或格位已占用时建造失败，资源和场上建筑均不改变。
7. 箭塔建造改为支付45木材与10石材；支付失败时箭塔不出现，支付成功后仍维持Story-002战斗数据。
8. 重置对局后资源清零、3个聚落格清空、箭塔移除并返回 `BOOT`。
9. Story-001～003与伤害公式继续通过回归测试。

## 范围外

- 波次结束后的生产、食物消耗、人口岗位分配和饥饿。
- 资源建筑受伤、耐久、拆除和材料返还。
- 城墙、兵营的实际建造与战斗效果。
- 第2波后的商店、金币购买和刷新。

## 依赖

- Story-003已完成。
- 开局六卡数据与20秒白天阶段。
- 单夜十波GDD批准的开局资源和建筑费用。

## 验证证据

| 验收项 | 状态 | 证据 |
|---|---|---|
| 1～8 | 通过 | Godot 4.7经济交互测试验证初始资源、免费选卡、原子扣费、三聚落格、卡牌锁定、非法建造、箭塔付费与重置清理。 |
| 9 | 通过 | Story-001～003及伤害公式回归测试全部通过。 |

## 验证命令

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_story_004.ps1
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_resource_building_placement.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_opening_day_draft.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_arrow_tower_wave_clear.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_first_wave_integration.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/test_damage_calculator.gd
```
