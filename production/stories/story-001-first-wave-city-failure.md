# Story-001：第1波野狼进攻与主城失败

> 状态：完成  
> 创建：2026-08-27  
> GDD：[单夜十波系统](../../design/gdd/single-night-wave-system.md)、[克制系统](../../design/gdd/counter-system.md)  
> ADR：[Godot平台基线](../../docs/architecture/adr-0001-godot-platform-baseline.md)

## 用户故事

作为第一次进入灰盒的玩家，我希望开始第1波后能看到野狼沿路线冲向主城并持续攻击，直到主城被摧毁并明确显示失败，从而理解最基础的防守目标。

## 验收标准

1. 从白天准备进入第1波战斗时，按0.6秒间隔生成4只野狼，总威胁点为20。
2. 野狼沿固定路线向主城移动，生成后的前2秒移动速度乘以1.3。
3. 野狼进入主城攻击距离后停止移动，每0.9秒发起一次8点基础物理攻击。
4. 主城拥有600耐久、10护甲；使用批准公式后每次野狼攻击造成7点最终伤害。
5. 主城耐久归零的同一逻辑更新内进入 `RUN_LOST`，全部敌人立即停止移动和攻击。
6. 失败界面显示“主城已被摧毁”，玩家可重置回 `BOOT`，场上敌人全部清除。
7. 敌人数值与第1波编成保存在资源数据中，UI不持有权威生命或伤害状态。

## 范围外

- 防御塔、城墙、敌人受伤和死亡。
- 20秒选卡、资源、人口和建筑放置。
- 第2～10波、怪物王、黄金凤凰、广告续战和排行榜。
- 正式像素素材、音效、震动与伤害飘字。

## 依赖

- `project.godot`
- `src/core/run_state.gd`
- `src/main/main.tscn`
- Godot 4.6或4.7兼容的GDScript与GL Compatibility。

## 验证证据

| 验收项 | 状态 | 证据 |
|---|---|---|
| 1 | 通过 | `wave_01.tres`为4只、0.6秒间隔；集成测试确认总威胁20且生成4只。 |
| 2 | 通过 | `wolf.tres`保存1.4格/秒、2秒×1.3疾冲；集成场景实际抵达主城。 |
| 3 | 通过 | `wolf.tres`保存8伤害/0.9秒；集成场景持续攻击至主城归零。 |
| 4 | 通过 | `test_damage_calculator.gd`确认8伤害攻击10护甲结果为7。 |
| 5 | 通过 | 集成测试确认耐久为0、阶段为 `RUN_LOST`，4只敌人位置随后保持不变。 |
| 6 | 通过 | 集成测试触发失败面板的重新开始按钮，确认回到 `BOOT` 且敌人清零。 |
| 7 | 通过 | 敌人与波次数据分别位于 `wolf.tres`、`wave_01.tres`；静态检查通过。 |

## 验证命令

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_damage_calculator.gd
godot --headless --path . res://tests/test_first_wave_integration.tscn
powershell -ExecutionPolicy Bypass -File .\tools\check_story_001.ps1
```

验证环境：Godot 4.7-stable；全部命令退出码为0。
