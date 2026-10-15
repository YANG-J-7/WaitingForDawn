# 月夜草地素材 v2

2026-09-30按用户提供的夜间聚落设计图调整：灰蓝土色、短草簇、暗底与灰绿亮尖，避免亮绿地毯压平山坡。美术通过内置图像生成制作，脚本仅负责切片、色彩均衡、最近邻采样、12色量化、边缘闭合和混铺预览。

## 文件与来源

- `moonlit_grass_draft.png`及同名提示词：设计图与当前地面底图共同参考的首稿。
- `moonlit_grass_source.png`及同名提示词：以首稿为图像编辑目标，提高草簇局部对比并减少零碎噪点的最终源稿。
- `moonlit_grass_atlas.png`：144×36 RGB图集，横排四个36×36地块。
- `grass-1.png`～`grass-4.png`：可单独放置和复用的四个36×36地块。
- `moonlit_grass_preview.png`：四变体稳定加权混铺的最近邻预览。
- `terrain-bundle.json`：技能标准交换清单；路径均相对本目录。质量阈值采用默认0.035对比度、0.025变体差异，未放宽。

## 在本项目中复用

权威逻辑网格始终为36世界像素。`TerrainGridLayer.grass_cells_per_tile`控制素材覆盖范围：1表示单格36×36，2表示2×2格72×72，本图默认2以提升放大后草簇的可读性。每个原始像素整数放大，不进行平滑采样；最后不足两格的一行裁切而非压缩。建造占地、寻路和地形规则均不受此显示参数影响。标准清单的`world_size=36`是单格交换规格，实际场景72像素展示由项目参数管理。

四变体共用12色色板和边缘色，可任意相邻。稳定坐标哈希与50%基础草地权重避免规则条带；放置时不要随机旋转受光方向，也不要启用线性过滤或有损纹理压缩。

草地材质通过`grass_relief.gdshader`保护底图中的冷蓝岩面、湖水和6像素坡脚过渡，结合大尺度底图明暗调整草地亮度；细节对比0.62只调整颜色，不模糊边缘。岩石与湖水沿用原图，资源、树木、建筑与单位保持独立节点。草地不再以逻辑崖壁格的矩形边界截断。

另一张地图可直接复用四张独立草地块；若复用保坡材质，必须给`relief_source`指定与新地图尺寸和冷蓝岩面配色一致的底图。当前基于颜色的视觉保护不等于通用高度图，也不用于推断碰撞；不同配色地图需要调整遮罩或另制独立保护图。旧岩石底图的源图细节没有被重新制作，最终审美仍待用户评审。

## 重建与验证

```powershell
python tools/build_moonlit_grass_tileset.py --input assets/tilesets/moonlit_grass_v2/moonlit_grass_source.png --output-dir assets/tilesets/moonlit_grass_v2 --native-pixel
python C:/Users/y1971/.codex/skills/generate2dmap/scripts/extract_terrain_tiles.py --input assets/tilesets/moonlit_grass_v2/moonlit_grass_atlas.png --output-dir assets/tilesets/moonlit_grass_v2 --rows 1 --cols 4 --terrain-row grass=0 --tile-size 36 --prompt assets/tilesets/moonlit_grass_v2/moonlit_grass_source.prompt.txt --edge-policy seamless --runtime-world-size 36 --surface-y 0 --strict-qc
godot --path . res://tools/check_terrain_visuals.tscn
```

技能脚本路径需按本机安装位置调整；最后一条必须使用真实图形后端，禁止加`--headless`。截图写入本机忽略目录`.codex-temp/terrain-relief/`，本次验收图另存于`tests/reports/images/terrain-relief-20260930/`。
