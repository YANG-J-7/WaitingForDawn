# ASSET-MOONLAKE-WIND-GRASS-V1 · 月湖山谷风动草簇

2026-11-10 · 候选 · 已接入 Story-039 的 P3 整关预览。

以[现行美术圣经](../../art/art-bible.md)与[草地风动设计](grass-field-wind-v1.md)为依据。表现为四种低矮、哑光的青绿草簇，在平原、林缘和山台稀密错落。土壤与底草维持原静态材质，地面上单独放置草叶。

- 由内置图像生成制作 1254×1254 洋红底四格原稿，以 P3 主城附近的真实夜景为色调参考。原稿随资产保留，SHA-256 为 `4c7f94ddb77e2cccca4f1ab94808c43acdd26c7d4a5f005d1fd55bc811eaddec`。[原稿](../../../assets/map_kits/moonlit_v3/grass/source/raw-sheet.png) · [生成提示词](../../../assets/map_kits/moonlit_v3/grass/prompt-used.txt)
- 使用 `generate2dsprite process --target asset --mode single --rows 2 --cols 2 --cell-size 128 --fit-scale 0.78 --align feet --scale-strategy preserve --component-mode largest --strict-qc` 去底和对齐。交付 256×256 RGBA8 图集，四格根锚点为每格的 (64, 114)。四格是外观变体，风动由连续顶点形变驱动。
- 根据关卡草地类别固定散布，按地表高度贴根，使用已有地图区块批绘。草叶沿世界坐标风场错相摆动，越靠根部位移越小。暂停和结算冻结，重开归零。草簇不参与拾取、碰撞和寻路，建筑占地隐藏相应草簇，释放时恢复。道路、石阶、裸岩和水面不布草，主城院落留空，布防远景与总览隐藏草簇层。
- 四格均通过透明边缘检查，且无裁切、粘连和可见洋红残色。1280×720 GL 实测 2,727 撮草簇贴地，24 帧同镜头采样可见草叶运动。4K 细节、整关负载和人工观感待复核。
