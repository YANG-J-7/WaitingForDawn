# 湖水与岩岸首批候选（ASSET-0019）

2026-11-12后续已制作独立动态样区：`res://tools/preview_lake_shore.tscn`。运行素材与接触线位于`runtime/`，水面已周期闭边；原始候选图不覆盖。贴岩水线、湖面波纹和月光可分阶段查看，暂停/复位共用12秒时钟。GL13项通过，单片/分块及回环最大差≤1/255。飞溅水滴、完整岸段连接与正式地图接入待办。详见`design/levels/lake-shore-preview/README.md`；下文“严格周期未通过”等只指原始交付水面。

2026-11-12，按用户确认的方案使用内置 image_gen 生成。当前为素材候选，未接入正式地图。

- `water.png`：1254×1254原生深宝蓝湖水底纹，不透明。`water-repeat-2x2.png`为原图直接拼铺，严格周期无缝尚未通过。
- `shore-transparent.png`：从独立生成的1774×887湖岸品红原稿确定性去底后，保留原生像素裁去留白；包括草顶、矮岩壁与浅水裙边。草地上缘与浅水外缘仍需接入时匹配，不是任意拼接岸线库。
- `combination-preview.png`：1774×887参考生成的组合效果图，仅展示视觉方向；模型重绘了局部细节，不作为独立素材真实拼接或引擎表现的证据。
- `*-prompt.txt`、`*-raw.png`、`reference.png`、`manifest.json`保留提示词、原稿、参考、来源和哈希。草地参考为`assets/map/grass_variants_v1/grass.png`。
- `processed/`为generate2dsprite去底、单帧导出和严格QC证据；其中GIF只有一帧，素材为静态。正式长条交付使用`shore-transparent.png`，不使用方形处理画布。
- `lake-shore-v1.zip`包含交付素材、组合预览、拼铺预览与说明。`build_delivery.py`只负责后处理与检查，不绘制原始美术。

验证范围：PNG解码、原生尺寸、四块拼铺与原图一致、湖岸透明边界与无可见品红、处理器无空帧/触边/裁切、ZIP完整性。水面边缘差见manifest，不能称为严格无缝。最终审美、真实草地接合、4K与Godot运行、碰撞/导航未验；未增加地形或天气规则。
