# 山坡湖泊地图候选

- `moonlit_hillside_lake.png`：上一版 1400×600 地面候选，保留作历史对照。
- `moonlit_hillside_lake_large_base.png`：新版 2800×1200 地面底图；湖泊接通右边界和下边界。
- `moonlit_hillside_lake_large_dressed_reference.png`：图像生成的树林布置参考，不用于运行时。
- `moonlit_hillside_lake_large_props.json`：700 棵复用针叶树的独立摆放数据，坐标以左上角为原点，`x/y` 是树的底部中心。
- `moonlit_hillside_lake_large_preview.png`：由地面底图和独立针叶树素材合成的审阅预览，可用 `python tools/build_moonlit_hillside_preview.py` 重建。

这组1400×600和2800×1200候选保留作历史对照，不再由主场景引用。

## 16:9 资源点候选（2026-09-22）

- `moonlit_resource_map_16x9_base.png`：2880×1620 地面底图，湖泊连通右侧和下侧边界。
- `moonlit_resource_map_16x9_border_forest.png`：运行时独立边界树林透明图层。
- `moonlit_resource_map_16x9_preview.png`：地面、边界针叶树、四处树林、两处石矿和两处铁矿合成的审阅图。
- `moonlit_resource_map_16x9_sites.json`：八处标注资源点的世界坐标、接收卡牌、放置半径与独立素材路径。
- `resource_sites/`：可重复放置的透明树林、石矿和铁矿 PNG 及生成原稿／提示词。
- `python tools/build_moonlit_resource_map.py` 可从地面、独立素材原稿重建预览和位置数据。

这组素材已由Story-027接入主场景，作为唯一运行地图。伐木场、石矿场和铁矿场匹配对应资源点，农场可在草地自由建造；湖泊内部已有保守禁建区。精细岸线、绕湖导航、坡地规则和完整60分钟运输体验仍待验证。

## 36像素草地TileSet（2026-09-28）

- `../tilesets/moonlit_grass_v1/moonlit_grass_atlas.png`：运行时使用的144×36图集，含4个36×36草地变体。
- `../tilesets/moonlit_grass_v1/grass-1.png`～`grass-4.png`：可单独复用的拆分地块。
- `../tilesets/moonlit_grass_v1/terrain-bundle.json`：网格、世界尺寸、提示词溯源、材质与质量检查数据。
- `../tilesets/moonlit_grass_v1/moonlit_grass_preview.png`：多格混铺预览，不作为运行贴图。
- `tools/build_moonlit_grass_tileset.py`：从保留的2×2图像生成源稿重建36像素图集与预览。

草地格已由`TerrainGridLayer`按坐标稳定选取变体；逻辑地形、寻路、建造与碰撞仍由`GridMapModel`独立管理。水岸和崖壁暂时继续使用Story-030程序表现。
