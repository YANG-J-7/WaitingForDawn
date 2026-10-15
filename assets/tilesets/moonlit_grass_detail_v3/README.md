# 原生细草叶可复用图集（2026-10-08）

用于最大1.6倍率不显粗像素方块，和建筑一样保留高密度源稿后缩小显示。逻辑格仍为36世界像素；每张地块显示为72×72、覆盖2×2格，不改建造、占用、寻路或地形碰撞。

## 文件与来源

- `moonlit_grass_refined_source.png`：采用的内置图像生成第二稿，实际1254×1254；草叶形状来自生成图，不是程序绘制或旧36像素图放大。
- `moonlit_grass_refined_source.prompt.txt`：第二稿完整提示词。参考本目录首稿与`assets/art_candidates/night_set_v1/town_hall.png`，校准细节密度、冷蓝地面和月光草叶。
- `moonlit_grass_source.png`与`.prompt.txt`：第一稿溯源。第一稿变体差异约0.022，未过0.025门槛，仅保留，不作为运行输出；第二稿最小差异0.025103，通过默认门槛，未降低QC标准。
- `moonlit_grass_atlas.png`：2508×627运行图集，四张627×627原生地块横排；共享64色、RGB、不透明。
- `grass-1.png`～`grass-4.png`：四张可单独复用的地块。
- `terrain-bundle.json`：标准清单、72世界像素显示尺寸、无缝策略、提示词与QC。
- `moonlit_grass_preview.png`：12×8混铺预览，预览缩略不影响运行图集尺寸；不是运行贴图。

所有象限先均衡平均RGB，再共享色板量化、闭合一源像素边缘。不将源稿缩到36像素；也不通过平滑滤波伪造细节。Godot导入Lossless、Nearest、无mipmap；`TerrainGridLayer.grass_source_rect`将贴图分辨率与世界格解耦，末行仅裁相应源区域。

草地密度约8.7083源像素/世界像素，当前主城约10.5778（可见主体90世界像素宽），比值82.3%。最大1.6镜头草地源像素约0.184屏幕像素，旧v2为3.2。RGBA8解码约6MiB，全图重复块共用同一纹理；最终远景噪点、窗口放大观感与性能压力测试仍待用户验收。

## 重建

在项目根目录执行，Python需要Pillow；第二步使用`generate2dmap`技能提供的提取器，按实际技能安装路径替换：

```powershell
python tools/build_moonlit_grass_tileset.py --input assets/tilesets/moonlit_grass_detail_v3/moonlit_grass_refined_source.png --output-dir assets/tilesets/moonlit_grass_detail_v3 --detail-native
python C:/Users/y1971/.codex/skills/generate2dmap/scripts/extract_terrain_tiles.py --input assets/tilesets/moonlit_grass_detail_v3/moonlit_grass_atlas.png --output-dir assets/tilesets/moonlit_grass_detail_v3 --rows 1 --cols 4 --terrain-row grass=0 --tile-size 627 --prompt assets/tilesets/moonlit_grass_detail_v3/moonlit_grass_refined_source.prompt.txt --edge-policy seamless --runtime-world-size 72 --surface-y 0 --strict-qc
```

复用时保持72世界像素显示尺寸，变体索引0～3对应`x=索引×627`的源区域。单张完整源区域627×627；显示高度不足72时按`显示高度×627/72`裁源高度，不挤压完整纹理。其他地图仍需独立定义玩法数据，不从草图颜色推断碰撞。

已通过默认严格QC、边缘一致性、7项确定性重建、60项专项及真实GL最大倍率对照；完整证据见`tests/reports/qa-2026-10-08-grass-detail.md`。旧v2保留作对照，不覆盖旧素材。
