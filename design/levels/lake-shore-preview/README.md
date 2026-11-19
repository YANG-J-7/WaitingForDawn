# 湖岸分层动态样区

2026-11-13独立水花：ASSET-0021六阶段生成素材已接凸岩、小湾、碎石岸三处，固定碰撞根点、独立尺寸/强度和错峰周期；顶部第二阶段为“拍岸水花”。完整60fps视频为本机`tests/reports/images/lake-shore-runtime/lake-animation-splashes-60fps.mp4`，GL29项与720帧/12秒完整解码通过。原有岩石静止保护继续通过；三处粒子另用人工核对的水侧裁切平面，避免进入后方岸石。详见[水花样区记录](splash-2026-11-13.md)，下文“无独立飞溅素材”等为此前历史状态。

2026-11-13碎石修订：主视频改为`tests/reports/images/lake-shore-runtime/lake-animation-fixed-rocks-60fps.mp4`，旧smooth视频保留但不代表修订效果。岸图/提取水线UV固定，独立水纹只在保守纯水遮罩内改变反射，背景水纹也避开非水保护图。左中右八处石头核心×12时刻逐像素固定，GL21项通过。新增`runtime/water-only.png`与`rock-only.png`均为原素材的控制遮罩，不是新绘制美术。浅水现在表现反射变化，不再扭动含砾石的原画；详见[修复记录](fix-2026-11-13.md)。

2026-11-13后续：主预览升级为`tests/reports/images/lake-shore-runtime/lake-animation-smooth-60fps.mp4`，720独立帧/960×540/12秒，完整解码计数通过，保持原动画速度。`tools/export_lake_sample.py`默认60fps，可用`--fps 30`重导保留的30fps源帧；GIF仍15fps。GL20项通过。以下30fps交付描述为上一轮记录；视频导出帧率不代表全关性能保证。

2026-11-13更新，实现Story-033的独立湖岸制作样区。正式关卡未接入。用户指出首版只有月光区域明显在动且卡顿，已增强全湖波纹、补上浅水扰动并改高帧率预览，详见[修复记录](fix-2026-11-13.md)。

打开`res://tools/preview_lake_shore.tscn`后按F6。顶部依次比较静态衔接、拍岸水线、湖面波纹、月光碎点；暂停冻结全部动画，复位回到12秒循环的起点，Home看全图，滚轮锚点缩放，中键拖动。

实现结构：`src/gameplay/art/lake_sample.gd`承载样区；水面、静态岩岸、水线为独立图层。水纹与月光采用世界坐标，四块水面共用时钟和材质，不在每个区块重新开始采样。局部接触线及控制图阻止反光进入岸石；岩岸无顶点或位置动画。月光中心是样区固定位置，尚未接入正式60分钟移动主光。

美术全部来源于ASSET-0019已生成原稿；`assets/map/lake_shore_v1/prepare_runtime.py`只做48像素对称周期闭边、抗锯齿残色清理、透明边缘过渡、接触线遮罩和原画水线提取。水花本版为贴岩水线的推进/消退，没有飞溅水滴或新序列帧；后续可在同一接触线叠加独立生成的飞溅动画，不必重画岸石。

源稿保留不覆盖；运行文件位于`assets/map/lake_shore_v1/runtime/`。`layout.json`记录接触线与样区尺度；当前接触线是本岸段人工校核近似，不是任意岸段或导航数据。当前场景固定为1920×1080样区，不能直接扩展为全关湖泊；完整岸段连接、禁建/通行、小地图、4K和大范围性能待后续。

真实GL验证脚本：`tests/test_lake_shore_runtime.tscn`；必须以GL渲染运行，不接受headless空图。当前20项覆盖静态输出、分块差异、六个水区在关闭月光后仍有变化、陆地隔离、暂停/恢复/复位、12秒周期与无截图读回帧间。`tools/export_lake_sample.py`从360张实际渲染帧导出30fps/12秒MP4，并制作15fps固定调色板GIF；需要Python的numpy、Pillow与imageio-ffmpeg。旧4fps GIF为历史，已被替换。

证据保留在本机忽略的`tests/reports/images/lake-shore-runtime/`，含四阶段1920×1080PNG、循环首尾、360帧960×540连续PNG、30fps MP4、15fps GIF、frame-times和metrics；旧48帧仅作历史。最终草叶尺度、上缘衔接、浅水外缘和动画强度仍需用户视觉复核，不以数值检查代替最终美术验收。

实现依据：[Godot CanvasItem着色器](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)；本机Godot 4.7 Standard、GL Compatibility实际验证。自定义elapsed用于统一暂停与复位，不依赖内置TIME。
