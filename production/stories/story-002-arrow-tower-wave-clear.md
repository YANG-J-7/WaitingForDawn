# Story-002：箭塔攻击、野狼死亡与第1波清场

> 状态：完成
> 创建：2026-08-28
> GDD：[核心系统](../../design/gdd/core-loop-system.md)、[克制系统](../../design/gdd/counter-system.md)、[单夜十波系统](../../design/gdd/single-night-wave-system.md)
> ADR：[Godot平台基线](../../docs/architecture/adr-0001-godot-platform-baseline.md)

## 用户故事

作为第一次布置防御的玩家，我希望看到箭塔自动锁定最接近主城的野狼、造成克制伤害并清空第1波，从而理解“建造防御可以阻止主城被摧毁”的核心反馈。

## 验收标准

1. 灰盒地图在主城前方放置1座箭塔；箭塔数据为12基础伤害、0穿甲、0.8秒间隔、4.5格射程。
2. 箭塔只在 `WAVE_COMBAT` 中攻击射程内敌人，优先选择沿路线最接近主城者。
3. 箭塔攻击野狼读取数据中的1.35克制倍率，单次最终伤害为16，不重复叠乘。
4. 野狼拥有55生命、0护甲；生命归零时只触发一次死亡事件并停止移动、攻击。
5. 4只野狼全部死亡且已全部生成后，第1波只结算一次清场，状态进入 `WAVE_RESULT`，波次推进到2。
6. 第1波清场时主城耐久大于0，界面显示“第1波已清空”。
7. 重置后清除敌人、箭塔累计伤害与击杀数，恢复 `BOOT` 和600主城耐久。
8. Story-001的无防御失败路径继续通过自动化回归测试。

## 范围外

- 箭矢投射物、正式动画、音效和伤害飘字。
- 卡牌选择、资源扣费、玩家放置或拆除箭塔。
- 多座塔、集火命令、其他敌人和第2波实际战斗。
- 波间商店、生产、广告和排行榜。

## 依赖

- Story-001已完成。
- 现有伤害公式、野狼数据、第1波数据和波次状态机。
- Godot 4.7-stable用于当前验证，新增代码保持4.6/4.7兼容。

## 验证证据

| 验收项 | 状态 | 证据 |
|---|---|---|
| 1～7 | 通过 | Godot 4.7集成测试验证箭塔配置、目标优先级、16点克制伤害、4只野狼死亡、单次清场、波次推进、界面提示与重置。 |
| 8 | 通过 | Story-001无防御失败集成测试继续通过。 |

## 验证命令

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_story_002.ps1
powershell -ExecutionPolicy Bypass -File .\tools\check_story_001.ps1
powershell -ExecutionPolicy Bypass -File .\tools\check_project.ps1
Godot_v4.7-stable_win64_console.exe --headless --editor --path . --quit
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/test_damage_calculator.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_first_wave_integration.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_arrow_tower_wave_clear.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 5
```
