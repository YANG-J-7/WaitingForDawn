# QA：36×36草地TileSet

> 日期：2026-09-28～2026-09-29
> 结论：通过；草地图集已接入，水岸与崖壁仍为程序表现

## 范围

- 4个36×36月夜草地变体、144×36运行图集、拆分地块、混铺预览和提示词溯源。
- `TerrainGridLayer`按权威网格绘制草地图集，最近邻过滤保持不变。
- 草地视觉与`GridMapModel`地形、建造、寻路和碰撞数据继续解耦。

## 自动化证据

- 图集质量检查：`generate2dmap.terrain_tile_bundle.v1`严格模式通过；最低对比度阈值0.018、最低变体差异阈值0.018、0条警告。
- 地形专项：`test_terrain_grid_rendering.tscn`，30项通过。
- GL Compatibility真实输入冒烟：`test_settlement_ui_smoke.tscn`，28项通过；AMD Radeon 780M / OpenGL 3.3，截图位于`.codex-temp/ui-settlement/`。
- 全量回归：29组、1079项通过、0失败；日志位于`.codex-temp/qa-20260929-165235/`。
- Godot 4.7 headless编辑器导入与脚本解析通过。

## 人工检查

- 已检查`moonlit_grass_preview.png`：四个变体平均亮度一致，格边闭合，加权混铺无透明缝隙或固定周期条纹；纹理变化在2倍最近邻预览中可辨。
- 已检查GL截图`battle.png`与`footprints.png`：草地在实际960×540场景和建造网格叠加下可见，资源点、建筑与HUD保持清晰。
- 源稿不用于运行时；运行时只加载36像素图集。

## 已知限制

- 当前只完成草地材质；水面、岸边、崖壁连接块仍为程序绘制。
- 尚未完成全图、1.0和1.5倍率的人工游戏内截图对比，也未完成建筑/单位Y排序专项。
