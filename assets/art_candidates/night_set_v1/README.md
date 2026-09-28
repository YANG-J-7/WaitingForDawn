# 夜间聚落素材候选 v1

来源：2026-09-20 使用内置 `image_gen`，按用户提供的概念图作**视觉参考**，逐个对象独立生成。参考图没有被裁切。19 张 PNG 保留为高分辨率源候选；当前 Godot 原型通过 `ArtVisual` 按透明主体裁切和原型比例显示，正式低分辨率逐帧稿仍待制作。永久 ID 与文件对应如下。

| ID | 文件 | 对象 | 状态与主要待验 |
|---|---|---|---|
| ENV-001 | `terrain_grass.png` | 草地基底 | candidate；四边无缝与不透明度待修 |
| ENV-002 | `terrain_road.png` | 石土道路基底 | candidate；四边无缝与接缝变体待修 |
| ENV-003 | `pine_tree.png` | 针叶树 | candidate；地图尺寸与脚点待验 |
| ENV-004 | `boulder.png` | 岩石堆 | candidate；缩略图待验 |
| ENV-005 | `torch.png` | 火把 | candidate；火焰动画待制 |
| ENV-006 | `bridge.png` | 木桥 | candidate；需与水岸 TileSet 配套 |
| BLD-001 | `town_hall.png` | 主城 | candidate；尺寸、轮廓、占地待验 |
| BLD-002 | `lumberyard.png` | 伐木场 | candidate；缩略图待验 |
| BLD-003 | `farm.png` | 农场 | candidate；农田与建筑拆层待验 |
| BLD-004 | `arrow_tower.png` | 箭塔 | candidate；缩略图待验 |
| BLD-005 | `palisade_wall.png` | 木城墙直段 | candidate；两端拼接待修 |
| BLD-006 | `quarry.png` | 采石场 | candidate；缩略图待验 |
| BLD-007 | `house.png` | 民屋 | candidate；缩略图待验 |
| BLD-008 | `barracks.png` | 兵营 | candidate；与主城区分待验 |
| BLD-009 | `windmill.png` | 风车 | candidate；目前仅作场景候选，不表示可玩卡牌 |
| ENV-007 | `mine_entrance.png` | 矿洞入口 | candidate；目前仅作场景候选，不表示金矿重新进入卡池 |
| CHR-001 | `villager.png` | 村民 | candidate；单姿态，动画缺失 |
| CHR-002 | `guard.png` | 守卫 | candidate；单姿态，逐帧动画缺失 |
| ENM-001 | `wolf.png` | 野狼 | candidate；单姿态，动画缺失 |

## 生成提示记录

工具：内置 `image_gen`，每个对象单独调用。公共方向：深蓝月夜的中世纪生存策略游戏、3/4 俯视斜角、暖橙灯火只用作局部焦点、清楚的像素块、独立物件居中、透明背景、无文字／界面／水印。草地与道路改为正上方平铺地面，并要求四边连续。各对象追加的主体描述：

| 文件 | 主体提示 |
|---|---|
| `terrain_grass.png` | 暗青蓝草地，少量苔藓与草簇，低对比平铺。 |
| `terrain_road.png` | 蓝灰色压实土与不规则石板，完整道路平铺面。 |
| `pine_tree.png` | 分层三角针叶树，冷月光边缘，短树干。 |
| `lumberyard.png` | 茅顶木屋、圆木堆、劈柴台、斧。 |
| `farm.png` | 小围栏、整齐麦田和蔬菜田垄、工具棚。 |
| `arrow_tower.png` | 木石高塔、架高平台、深色尖顶、小火把。 |
| `palisade_wall.png` | 五根尖木桩构成的直墙段，无门。 |
| `quarry.png` | 木棚、灰石、方石、手推车、灯。 |
| `town_hall.png` | 有红褐陡屋顶、石基、木上层、明亮入口的小型主城。 |
| `house.png` | 简单低矮民屋、深色屋顶、一扇暖窗、小烟囱。 |
| `barracks.png` | 木石兵营、盾架、训练枪、灯。 |
| `windmill.png` | 石基木身、四片风帆的风车。 |
| `mine_entrance.png` | 岩壁矿洞口、木支架、短轨道、矿车和灯。 |
| `boulder.png` | 三块低矮蓝灰岩石与小碎石。 |
| `torch.png` | 单根木制路边火把、铁箍、琥珀色火焰。 |
| `bridge.png` | 短木板桥、低护栏、石砌桥台，无水面。 |
| `villager.png` | 棕色衣服的成年农民，站立 3/4 视角，无武器。 |
| `guard.png` | 蓝衣、铁盔、圆盾、短枪的城镇守卫，3/4 视角。 |
| `wolf.png` | 炭黑色野狼，前倾奔跑，红眼小点，无血条。 |

## 原型内使用

- `res://src/main/main.tscn`：草地、主路、主城、外围针叶林和路灯；资源点、可建建筑、村民、守卫和野狼接入相应图片。手牌显示建筑图。
- `res://src/gameplay/art/art_gallery.tscn`：可独立运行的19项素材总览，包含尚无玩法用途的风车和木桥。
- `res://src/gameplay/art/art_visual.gd`：按实际可见主体裁去透明留白，再按[原型比例表](../../../design/art/art-bible.md#原型图比例校准2026-09-20)缩放；树木摇摆、单位步行起伏、火把与建筑灯光明暗为程序动画。地形和墙体保持静态。

上述动画不含逐帧奔跑、攻击、受击、死亡或风车叶片分层旋转。源图仍处于 `candidate`，当前接入只代表原型可加载和可试玩，不代表美术人工审批或最终纹理验收。

## 尚需制作的配套件

草地边缘、道路直线／拐角／T 字／十字／端点及草地过渡；水面与岸线；阔叶树／树桩／草簇；石矿脉与农田资源点的明确标记；城墙拐角／端点／门；主城围栏、路旗；守卫、农民和狼的逐帧动画；资源图标及九宫格 UI。手牌目前复用建筑源图，独立卡牌构图待制作。未来素材以 [美术圣经](../../../design/art/art-bible.md) 为准。地形、天气和新建筑是否具备玩法功能须由 GDD 决定。

## 交付门槛

当前完成 PNG 加载、默认镜头比例截图目检与游戏原型接入。下一步要人工清理像素网格与 alpha 边缘、制作正式尺寸导出稿、验证地面无缝和墙段拼接、检查其他缩放与窗口比例。未经这些检查，不把候选图写为最终正式素材。
