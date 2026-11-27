# 一级主城 · 守夜厅

## 2026-11-27 月夜重做版

以用户提供的[五级月夜总览](../../../design/art/concepts/town-hall-lighting-2026-11-26/README.md)左上守夜厅为方向，比对暗红瓦、蓝灰砖石、门廊台阶和旗帜的位置。正式第一关使用 [1027×972 主体](revision_2/body.png)和 [512×485 卡画](revision_2/card.png)。场景主体宽 224 世界单位，脚点在底边中心，门前草土使用独立的[透明贴图](revision_2/ground.png)。

旗布使用四张 94×123 RGBA 图，挂杆对齐。每盆火焰使用同一组四张 64×120 RGBA 图，以帧内 (32, 111) 为火根，错相循环。窗光和墙面受光跟随地图主光和游戏状态。原图哈希、提示词、裁切和检查结果见[生成记录](revision_2/generation-record.json)。

## 2026-11-26 初版存档

2026-11-26。按用户选定的[红瓦主城方案](../../../design/art/concepts/town-hall-levels-2026-11-25/README.md)单独生成，参考首版左上角的红瓦双坡、低蓝灰石基、木架和蓝金短幡。建筑主体为 922×818 RGBA PNG，脚点在底边中心。现场使用 184 世界像素的宽度和原始比例，地图主体与卡画共用贴图。[运行贴图](body.png)

原画由内置图像生成工具绘制，以纯洋红为背景。经 generate2dsprite 色键清理，确认单一主体无触边，再清理残色并裁出两像素留白。原画 SHA-256 为 `BAE3FACBD1C12CFD68F684BCD8302E413987BFB401727E0AB7A3765F72936770`，运行贴图 SHA-256 为 `F318E1501D77104BA89499C75EB268843F82FF0694CA4A8197903D5C7FEE60FE`。

该初版使用静态主体和绘制在窗内的暖色。二至五级升级条件与运行素材待后续制作。[开局 Story](../../../production/stories/story-036-place-town-hall-opening.md)
