# Story-026 QA：HUD程序化视觉实现

> 日期：2026-09-18
> 环境：Windows，Godot 4.7 Standard，GL Compatibility
> 结论：PASS WITH RISKS

## 已验证

- HUD按确认概念图改为单行顶栏、全宽横向手牌、动态建筑岗位浮层与右侧2×3商店抽屉。
- 商店展开时地图、敌人、运输、倒计时和底部手牌保持可见；岗位面板关闭，抽屉外地图仍可拖动与缩放。
- 商店显示1星、价格、持有数、合成缺口，以及购买、金币不足、手牌已满和已售罄文字状态；刷新显示当前与下次费用。
- `test_settlement_ui_smoke.tscn`：28项通过，覆盖真实鼠标拖动、建筑点击、岗位随镜头更新且不压手牌、商店展开与关闭、18张手牌及左右翻页。
- `test_hud_responsive_layout.tscn`：14项通过，覆盖1024×768与1280×720下顶栏/手牌贴边、商店宽度及不遮挡手牌。
- `test_free_wall_battle_shop.tscn`：46项通过；商店、购买、刷新与地图建造保持一致。
- `test_card_drag_placement.tscn`：44项通过；`test_manual_worker_assignment.tscn`：38项通过；`test_map_expansion.tscn`：50项通过。
- 全量自动化：24组973项断言通过。
- GL Compatibility真实窗口运行UI冒烟28项通过；`selection.png`、`building-workers.png`、`shop.png`、`full-hand.png` 已目检，位于本地 `.codex-temp/ui-settlement/`。
- Godot 4.7 headless解析通过。

## 剩余风险

- 尚未完成1280×720和非16:9窗口的人工体验；当前项目仍以960×540逻辑分辨率为实现基线。
- 尚未验证键盘焦点、手柄导航和屏幕阅读；项目没有正式无障碍等级文档。
- 当前使用Godot程序化样式和文字占位，没有正式像素图标、建筑卡图、字体或九宫格面板素材。
- 本轮未进行完整60分钟自然试玩，不评价长局平衡。
