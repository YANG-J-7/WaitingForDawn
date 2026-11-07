# Story-036 · 月湖山谷 3D 灰盒样区

状态：P0 灰盒已交付，技术验证通过，待使用者复核画面。更新于 2026-11-07。

依据：[月湖山谷 3D 地图与光影开发文档](../../docs/architecture/moonlake-3d-map-and-lighting-development.md)、[网格 GDD](../../design/gdd/grid-map-rendering-system.md)、[Story-033](story-033-modular-level-map.md)。

## 验收

1. 独立 Godot 场景能运行，可见平地、山台、S6 双段石梯与中间平台、湖岸和针叶林缘。
2. 可切换固定斜俯视的建设档与近景档，对照现有关卡网格查看平地和山台的样例占地。
3. 样区的 S6 石梯格、两端层级和两侧通路与现有 2D 关卡对应。通过原网格检查双向可达、岩壁和水域边界。

P1 承接真实建造、农民移动和小地图。P2 承接正式材质、主光及阴影对照。

## 运行与验证

- 在 Godot 打开 [样区场景](../../prototypes/moonlake_3d_graybox/moonlake_3d_graybox.tscn) 后按 F6。按 1、2、3 切换建设、近景、俯视，按 G 切换格线，左键读取原地图格坐标、地形和灰盒高度。
- 样区读取第一关山地与湖泊数据，覆盖原网格列 150～170、行 33～51，每格映射到 1 个 3D 水平单位。高度、岩壁形体和针叶树为灰盒占位，湖岸按原网格显示。
- Godot 4.7 无头专项 433 项通过。399 个地形格与原关卡运行网格一致，覆盖 S6 的 21 个格、两端道路双向通路及两处平整的 2×2 可建样例。
- Windows 1280×720 GL Compatibility 专项 445 项通过，含键盘切换三档、网格开关、五处鼠标读格以及三个档位的实景截图。截图已目检。正式主场景无头启动、项目结构和差异格式检查通过。全量历史回归本轮未运行。
- 本地证据位于 `.codex-temp/moonlake-p0-headless.log`、`.codex-temp/moonlake-p0-gl.log` 和 `.codex-temp/moonlake-p0-view-1.png` 至 `moonlake-p0-view-3.png`。

真实拖牌、地表拾取及农民贴地往返由 [Story-037](story-037-moonlake-3d-playable.md) 承接，P0 场景继续用于几何对照。
