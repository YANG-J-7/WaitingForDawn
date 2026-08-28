# Story-003：开局白天六卡选择与箭塔放置

> 状态：完成
> 创建：2026-08-28
> GDD：[游戏概念](../../design/gdd/game-concept.md)、[单夜十波系统](../../design/gdd/single-night-wave-system.md)、[核心系统历史基线](../../design/gdd/core-loop-system.md)
> ADR：[Godot平台基线](../../docs/architecture/adr-0001-godot-platform-baseline.md)

## 用户故事

作为第一次开始对局的玩家，我希望在明确的20秒白天阶段从六张免费卡中选择四张，并把箭塔放到合法防御格，然后迎战第1波。

## 验收标准

1. 点击“开始灰盒对局”后进入 `DAY_SETUP`，显示从20秒开始的倒计时、六卡面板与迎战按钮，敌人尚未生成。
2. 开局六卡固定包含3张资源建筑卡（伐木场、农场、金矿场）和3张防御建筑卡（箭塔、城墙、兵营）。
3. 玩家免费选择且最多选择4张；界面持续显示剩余免费名额，未满4张时迎战按钮不可用。
4. 选中箭塔后点击固定防御格，箭塔在该格出现并启用；未选择箭塔时不能放置。
5. 选满4张后可点击迎战，选择与布局锁定并只启动一次第1波。
6. 倒计时归零时稳定自动补足到4张并开始第1波；游戏树暂停期间倒计时不减少。
7. 重置后返回 `BOOT`，清空选择与倒计时，移除并禁用已放置箭塔。
8. Story-001失败路径、Story-002箭塔清场和伤害公式继续通过回归测试。

## 范围外

- 伐木场、农场、金矿场、城墙和兵营的实际建造与产出。
- 建筑资源扣费、人口岗位、卡牌储备上限和拆除。
- 第2波后的随机商店、购买、刷新与怪物王克制卡。
- 自由拖拽、多个格位、正式像素素材、音效和动画。

## 依赖

- Story-001与Story-002已完成。
- `RunState` 的 `BOOT → DAY_SETUP → WAVE_COMBAT` 状态转换。
- 现有箭塔、波次控制器和第1波数据。

## 验证证据

| 验收项 | 状态 | 证据 |
|---|---|---|
| 1～7 | 通过 | Godot 4.7交互测试验证20秒白天、暂停冻结、六卡分类、免费选四、选择上限、箭塔格位放置、提前迎战、超时补牌与重置。 |
| 8 | 通过 | Story-001失败、Story-002箭塔清场及伤害公式测试全部通过。 |

## 验证命令

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_story_003.ps1
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_opening_day_draft.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_arrow_tower_wave_clear.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/test_first_wave_integration.tscn
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/test_damage_calculator.gd
```
