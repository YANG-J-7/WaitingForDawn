# 主城贴地与待机素材规格 v2

日期：2026-10-23。用户确认概念方向并授权实施，素材状态为已接入运行候选，最终审美待用户复核。

参考：[设计图](../../art/concepts/town-hall-redesign-2026-10-23/town-hall-design-v1.png)、现有主城、[美术圣经](../../art/art-bible.md)。实施：[Story-032](../../../production/stories/story-032-town-hall-idle.md)。

| ID | 用途 | 规格 |
|---|---|---|
| BLD-TOWN-HALL-V2 | 稳定主体 | PNG RGBA，958×1043，显示180×176世界像素，底部中心脚点，4×4逻辑占格不变 |
| BLD-TOWN-HALL-SHADOW-V2 | 月光右下投影与接触影 | 从主体alpha确定性投影，1160×280及720×100，透明冷蓝灰，独立地面层，不写占格 |
| BLD-TOWN-HALL-FLAG-V2 | 顶部蓝金旗布 | 2×2生成稿、4个256×256透明帧，0.23秒/帧，金色绑点锁定旗杆 |
| BLD-TOWN-HALL-FIRE-V2 | 门前两簇火焰 | 2×2生成稿、4个256×256透明帧，0.12秒/帧，两处错相，根部固定 |
| BLD-TOWN-HALL-SMOKE-V2 | 烟囱薄烟 | 2×2生成稿、4个256×256透明帧，冷灰去紫、透明度0.32，0.65秒/帧交叉淡入 |

主体Nearest，投影与薄烟Linear；没有烘焙地面/草坪大贴片，不直接切割设计板。旗帜和火焰共享缩放、不逐帧归一化；烟形变化属于特效，不采用人形CV阈值。窗光由主体暖色窗芯掩码以3.5%幅度调制、使用显式游戏时钟，墙体与主体变换不摆动。建图、阴影和帧原点详见[运行清单](../../../assets/buildings/town_hall_v2/manifest.json)。

四张原稿与完整手写提示词见[来源目录](../../../assets/buildings/town_hall_v2/source/)，处理记录与透明序列帧见[素材包说明](../../../assets/buildings/town_hall_v2/README.md)。

验收：无空帧、触边、粘贴裁切，帧根部稳定；透明像素无高饱和洋红，重建确定性；暂停/恢复/重开/胜负/摧毁正确。三视口、最大镜头、真实GL阴影及循环预览证据见[QA](../../../tests/reports/qa-2026-10-23-town-hall.md)。
