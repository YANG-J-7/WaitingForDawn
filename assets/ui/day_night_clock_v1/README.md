# 黎明计时日月转换素材 v1

- 日期：2026-10-09；状态：candidate，已接入，最终美术复核待用户验收。
- 来源：用户提供的夜间守城HUD设计图及本轮红框反馈；使用内置 `image_gen` 独立生成，不从概念图裁取图标。
- 原稿：`raw-sheet.png`，1774×887，纯品红背景，2行4列，从左到右、从上到下共8帧。完整实际提示词见 `prompt-used.txt`。
- 后处理：`generate2dsprite` 技能脚本去品红、统一缩放、固定中心，输出512×256透明图集、8张128×128帧、透明清理稿、预览GIF和 `pipeline-meta.json`。
- 运行：`src/gameplay/art/day_night_clock.gd` 使用40×40逻辑画布与Linear过滤；保留所有帧公共画布，禁止逐帧裁剪后单独拉伸。
- 时间：整局圆弧按 `(3600−剩余秒)/3600` 推进；最后300秒，月牙沿8帧逐渐转为太阳，相邻帧按有效时间淡入。暂停冻结，重开复原；商店展开继续推进，结算停留当前帧。不引入昼夜属性或天气规则。
- `animation.gif` 是220毫秒/帧的快速循环素材预览；游戏内转换为一次性末段进程。实际胶囊加速预览另见QA报告，不代表自然试玩。

## 可复现处理命令

```powershell
python 'C:\Users\y1971\.codex\skills\generate2dsprite\scripts\generate2dsprite.py' process --input assets/ui/day_night_clock_v1/raw-sheet.png --target asset --mode hover --output-dir assets/ui/day_night_clock_v1 --prompt-file assets/ui/day_night_clock_v1/prompt-used.txt --rows 2 --cols 4 --cell-size 128 --fit-scale 0.80 --shared-scale --align center --component-mode all --scale-strategy fit --duration 220 --strict-qc
```

`hover` 仅为该脚本的通用输出模式名称，本素材是日月转换效果，运行逻辑不绑定鼠标悬停。8帧共用0.3953667954源到输出缩放。

## 技术检查

严格QC通过：有效帧8/8，空帧0，触边0，粘贴裁切0；输出主体平均高度82像素。归一化中心横向标准差0.0263、纵向0.0548。轮廓从月牙扩展为带光芒太阳，面积变化属于效果语义，人类角色的身体尺度CV不作为此效果的验收门槛；固定共享缩放未关闭。Godot导入、30项计时/帧专项与三视口GL检查通过。
