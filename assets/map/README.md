# 山坡湖泊地图候选

## 当前运行地图：分层大地图（2026-10-13）

主场景现用`dawn_large_v1/`，世界4608×2592、128×72格，36世界像素格保持。以下旧底图与草地版本保留作历史记录，不能据下方历史“当前”描述判断运行引用。

- `map.json`：地形格、8资源、12地形片、12岩缘遮挡、母图坐标及溯源；`src/gameplay/grid/map_definition.gd`为统一运行入口。
- `base.png`与`ground-*.png`：从母图拆分的地面，树下补地由内置image_gen生成；主场景按共边世界坐标绘制分块，不叠旧图专用草地/道路。
- `forest_*.png`、`border-forest.png`和`cliff-*.png`：独立树簇/边界树林及岩缘，树林占用隐藏、释放恢复；需要遮挡单位时淡化。
- `layered-preview.png`：离线初态合成与v2母图RGB最大差0；仅QA对照，不作为运行底图。
- `ground-fill-source.png`、同名提示词、`generation-record.json`：生成原稿和两次调用结果，实际原生1672×941，不声称3840×2160高清产物。
- `tools/build_layered_large_map.py`：确定性拆分、补地合成、显式地形标注与清单重建。

全量和GL证据见`tests/reports/qa-2026-10-13-layered-large-map.md`。当前放大清晰度受母图源分辨率限制，完整60分钟平衡与动态避让待后续；不得仅凭分块或世界扩大声称高清已完成。

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

草地格已由`TerrainGridLayer`按坐标稳定选取变体；逻辑地形、寻路、建造与碰撞仍由`GridMapModel`独立管理。以上v1为历史版本，当前状态以下方更新为准。

## 当前运行版本：清晰地形与高密度草地（2026-10-08）

- `moonlit_terrain_detail.png`：当前主场景和草地保坡材质共用的3344×1882高细节底图；世界仍2880×1620。岩缝、岩面亮暗与细水波由四片区内置图像生成编辑，不再降成1440×810后2倍整数复制，不量化为64色。仅底图与保护源使用Linear，草地、建筑和独立实体仍Nearest；Lossless、无mipmap。
- `moonlit_terrain_detail_source.png`及同名`.prompt.txt`：固定构图源稿，实际1672×941，不能将其直接放大冒充高细节稿。
- `terrain_detail_regions/`：四个编辑参考、独立生成的高细节源图和完整提示词。实际源尺寸1629×966、1628×966、1627×967、1628×966；规范到1800×1068/1070后，在重叠区沿最小色差路径拼接，4贴图像素窄羽化。最终3344×1882是合成尺寸，不是一次原生4K生成。
- `moonlit_terrain_detail.json`：真实源尺寸、各参考及源稿SHA256、拼接与采样规范；底图不能生成或覆盖碰撞。
- `moonlit_resource_map_16x9_terrain_crisp.png`：上一版2880×1620、64色、2×2整数复制底图，仅保留前后对照和回退，不再运行。
- `moonlit_resource_map_16x9_terrain_crisp_source.png`及同名`.prompt.txt`：内置图像生成的最终重绘源稿与手写提示词，实际源图1672×941，规范到1440×810原生格后整数放大；不声称生成了2880×1620原生细节。
- `moonlit_resource_map_16x9_terrain_crisp_draft_source.png`及同名`.prompt.txt`：首轮编辑稿和提示词。第一轮编辑旧底图，第二轮收紧岩块轮廓、裂缝和接触阴影，最终采用第二轮。
- `moonlit_resource_map_16x9_terrain_crisp.json`：源图、直接编辑参考的SHA256与采样/尺寸规范。图像仅定义外观，不能生成或覆盖碰撞。
- `moonlit_resource_map_16x9_base.png`：保留的旧底图，供前后对照和回退，不再用于主场景或草地保坡材质。
- 草地当前使用`../tilesets/moonlit_grass_detail_v3/`的四个627×627原生变体，默认每块覆盖72×72世界像素，即2×2逻辑格；逻辑网格仍为36世界像素。源纹理密度约为主城的82.3%，不是放大36像素旧稿。源稿、提示词、无缝清单和重建说明见该目录`README.md`；旧v2仅作历史对照。

重建当前精修地形（只拼接已有生成美术，不绘制地形）：

```powershell
python tools/build_detail_terrain.py assemble --reference assets/map/moonlit_terrain_detail_source.png --regions assets/map/terrain_detail_regions --output assets/map/moonlit_terrain_detail.png
```

边界树林、资源点、建筑与单位保持独立运行层，资源清单本轮只修改`base`路径；建造、寻路和阻挡仍由现有`TerrainMapData`/`GridMapModel`管理。草地保护材质与主底图引用同一张新地形图。此底图是既有地图的重绘，仍不是可任意拼接的水岸/崖壁地块；后续模块化地图不能直接将它当作通用TileSet。

旧`moonlit_resource_map_16x9_preview.png`是历史合成预览，当前运行全图、最大1.6倍率前后对照和接缝近景见`tests/reports/images/terrain-detail-20261008/`；`tools/build_moonlit_resource_map.py`重建预览时将高清底图规范到世界坐标尺寸，避免资源位移。本轮只在临时目录验证预览合成，不重写无关树林和矿点。

### 左侧平原局部清理（2026-09-30最终要求）

2026-09-30清理阶段不重新设计素材。最初仅清理红框矩形，之后扩大为上下延伸到地图边缘的22点平原轮廓。2026-10-08先接入高密度草地，再按用户新增要求精修底图并移除平原散石。新下方岸线略有偏移，旧清理轮廓会裁掉一段湖岸，因此当前22点轮廓在下部向内陆退让72～144世界像素；旧轮廓保留为`LEGACY_LEFT_PLAIN_CLEANUP_POLYGON`用于对照。仍通过`clear_left_plain_rocks`控制草地覆盖与统一调色，不影响独立矿点、树林或玩法阻挡。

所有平原共用`PLAIN_GRASS_LIGHT = 0.88`基准调色，避免局部清理的固定亮度与外围底图明暗不同形成补丁；仅未移除岩面40世界像素近邻保留坡脚明暗。草地逻辑格和碰撞规则不变；新草地密度及清理/调色回归见`tests/reports/qa-2026-10-08-grass-detail.md`，历史清理证据见`tests/reports/qa-2026-09-30-left-plain-expanded.md`。

当前精修与清理回归见`tests/reports/qa-2026-10-08-terrain-detail.md`。旧弃用草稿仍保留在本地临时归档，不自动恢复；当前精修是本次用户新增要求下的独立版本。

### 2026-10-10 山区道路与权威格细化

按用户新要求增加山区主干、四矿入口和山台支路，不重绘底图或移动八个资源点。道路源为2026-09-20独立生成的ENV-002石土候选，运行使用72世界像素路幅、共享世界UV和渐隐边缘；新土路/坡道图集生成两次HTTP429没有产物，已明确记录。来源与候选限制见`mountain_roads_v1/README.md`、`runtime-meta.json`。

`design/levels/mountain-rock-cells.json`以固定底图离线12×12取样登记岩面，代替旧三段粗崖壁范围；运行只读JSON。草台可走可建，裸岩不可走不可建，岩质坡道可走不可建；道路不加速，湖水和资源专用格规则不变。新路网同一JSON同时供显示与逻辑开放，换图须重新登记和目检36像素边缘。

58项山区、全量32组1290项及GL道路8项通过；实景、草台落成、四矿往返与来源限制见`tests/reports/qa-2026-10-10-mountain-roads-thin-hud.md`。自然长局经济与动态单位避让不作为本次已完成内容。
# 2026-10-14 大地图高清视觉与独立视口

当前运行视觉来自`dawn_large_hd_v2/visual.json`：12片高清地形、透明树簇、高清边界与同源岩缘。原生编辑稿、三份手写提示词和生成记录保存在同目录；5016×2823为分块合成尺寸，世界仍4608×2592。`dawn_large_v1/map.json`继续作为36像素权威地形/资源/台阶数据及历史母图对照。地图仅绘制在顶栏下缘与可见手牌上缘之间；全图模式等比居中，宽高比不同时留边。

树林不再因单位靠近淡化，资源占用仍隐藏，释放/重开恢复。单位视觉2.2倍、建筑2倍，HUD卡图和占格/经济保持；四边有随缩放保持可读的世界边框。验证见`tests/reports/qa-2026-10-14-map-visual-fixes.md`。
