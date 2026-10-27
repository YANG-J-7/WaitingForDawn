# 多关卡模块化地图方案检查记录

日期：2026-10-27。结论：设计资料定点检查通过；全项目素材校验存在10条既有编号缺失。新地图系统未实现，未生成新地图美术，未进行新方案GL或自然试玩验收。

## 交付范围

- [主方案](../../design/gdd/modular-level-map-system.md)：多关卡、组件与接口、玩法编译、出生/攻守地形、建造落地、镜头、密度、性能、M0～M5迁移与验收。
- [美术修订草案](../../design/art/map-art-bible-v2-proposal.md)：保留旧批准边界，新视觉方向和预算为提案。
- [首批生产计划](../../design/assets/map-kit-v2-production-plan.md)：12类环境/地物/底座，新增永久素材ID、详细规格与手写生成提示词。
- 现行美术圣经/系统索引仅增加入口；项目进度与当前目标同步。Story-031实现状态不因本轮设计改变。

## 资料和算例检查

本轮定点脚本`.codex-temp/check_modular_map_plan.py`以Python标准库运行：12个新ID唯一，规格存在，未生成/未批准/未接入标记正确，没有虚报`file`产物；15份新方案/规格文档中27个本地链接存在，代码围栏闭合。此检查针对本轮字段和引用，不宣称通用YAML语法解析或运行schema验收。

核对运行JSON：7056×2880、36格、196×80、主城(4176,1908)、4出生点、8资源、18地表片。计算P=960×391：fit=0.1357638889、cover=0.1360544218；4K k=4且z=1.6所需密度6.4，现草地横纵密度均约6.704。小样64×40格=2304×1440，预算示例224MiB；全图6.4密度烘焙RGBA8约3.1008GiB、完整mip约4.13GiB。以上为算例，不是本轮显存测量。

素材技能校验实际执行：

```text
py -3 C:/Users/y1971/.codex/plugins/cache/personal/codex-game-studios/0.1.0/scripts/validate_game_project.py --root .
```

结果FAIL：以下10个旧规格缺少该工具要求的ASSET编号，本轮修改前已复现；新增12份规格没有新增错误：

```text
grass-field-wind-v1.md
grass-redesign-v1.md
map-dawn-large-hd-v2.md
map-mountain-redesign-preview-v1.md
map-mountain-redesign-preview-v2.md
map-mountain-road-v1.md
town-hall-ground-base-v1.md
town-hall-idle-v2.md
ui-day-night-clock-v1.md
ui-hud-reference-v1.md
```

旧命名ID与已引用素材未批量改名。工具按全文匹配编号，规格路径里的大写编号也会被误计为重复；新规格文件及清单路径统一使用小写`asset-xxxx.md`，ID字段仍使用永久大写编号。未改插件校验器。

## 现有地图回归

Godot `D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe`，通过`pwsh -NoProfile -File tools/run_tests.ps1 -GodotPath <上述路径> -Filter <测试名>`执行：

| 测试 | 通过断言 | 日志目录 |
|---|---:|---|
| test_layered_large_map | 120 | `.codex-temp/qa-20261027-153003/` |
| test_wide_map | 24 | `.codex-temp/qa-20261027-153012/` |
| test_terrain_grid_rendering | 70 | `.codex-temp/qa-20261027-153019/` |

合计3组214项，0失败。最初使用Windows PowerShell 5直接读取UTF-8无BOM测试脚本时发生解析错误，未进入Godot；随后改用现有PowerShell 7运行同一未改脚本，以上为最终有效结果。没有为解决环境问题修改项目测试或安装依赖。

本轮目检的是10月27日既有`grass-static-2026-10-27/`中4:3全图与1280×720主城最大倍率截图，确认方案需处理留边、局部地基融合与高低密度材质。不把既有截图计为新架构运行证据；未重跑此前GL57项、38组全量或60分钟自然试玩。

结构检查与`git diff --check`通过。用户原有`.gitignore`、草地源码/素材/工具、旧方案/Story修改均保留；本轮不提交、不推送，不替换运行地图。

## 待验证

主方案、美术方向、操作/总览行为和首批范围待评审；未来先完成地图上下文与互动小样，证明第二布局能复用、接口自然、单位可达与建筑贴地，再迁移整关。预算/最低硬件、完整Y排序、首次寻路尖峰、动态避让、4K实际帧率和自然长局仍未解决。
