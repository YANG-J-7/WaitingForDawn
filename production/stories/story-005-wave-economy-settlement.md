# Story-005：第1波岗位与生产结算

> 状态：完成
> 创建：2026-08-28
> GDD：[单夜十波系统](../../design/gdd/single-night-wave-system.md)、[核心系统历史基线](../../design/gdd/core-loop-system.md)
> ADR：[Godot平台基线](../../docs/architecture/adr-0001-godot-platform-baseline.md)

## 用户故事

作为完成第1波防守的玩家，我希望已建建筑根据人口岗位产生资源，并支付本波人口食物，让白天的经营选择立即得到可读反馈。

## 验收标准

1. 第1波开始前自动分配6人口：已建箭塔优先分配1人，再按资源建筑建造顺序为每座最多分配2人，剩余人口计为空闲。
2. 资源建筑按 `floor(每波基础产出 × 已分配岗位 / 岗位上限)` 生产；伐木场、农场、金矿场满岗分别产出10木、8食、4金币。
3. 第1波全部敌人清空后只执行一次经济结算，顺序为先生产、再由全体6人口消耗6食物。
4. 建造伐木场、农场和箭塔的基准组合在第1波结算后得到10木与8食，随后消耗6食，最终相对战前净增加10木与2食。
5. 未建造或零岗位建筑不产出；1/2岗位按50%产出并向下取整。
6. 食物不足时只消耗现有食物、余额保持0并标记饥饿；任何资源不能变成负数。
7. 重复触发同一波结算不重复生产或扣食物；重置后清除岗位、饥饿和已结算波次记录。
8. 清场界面显示本波生产、食物消耗与岗位概况。
9. Story-001～004及伤害公式继续通过回归测试。

## 范围外

- 玩家手动调整岗位、人口增减、民居和征募。
- 饥饿带来的下一波产出与攻速惩罚，以及连续饥饿减员。
- 第2波商店和第2波实际战斗。
- 建筑维修、研究、拆除与被敌人摧毁。

## 依赖

- Story-004已完成。
- 资源建筑数据中的每波产出，以及局内经济原子变更接口。
- 第1波清场信号只发送一次。

## 验证证据

| 验收项 | 状态 | 证据 |
|---|---|---|
| 1～8 | 通过 | Godot 4.7集成测试验证防御优先岗位、满岗/半岗产出、先生产后吃饭、饥饿下限、幂等结算、重置与界面摘要。 |
| 9 | 通过 | Story-001～004及伤害公式回归测试全部通过。 |

## 验证命令

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_story_005.ps1
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_wave_economy_settlement.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_resource_building_placement.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_opening_day_draft.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_arrow_tower_wave_clear.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_first_wave_integration.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/test_damage_calculator.gd
```
