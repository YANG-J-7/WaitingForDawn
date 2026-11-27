# 第一关双人转身与跑动预览

麦秆帽男农民和浅头巾女农民各有两组四帧动作。原地转身依次朝右下、左下、左上、右上。跑动面向右下，交替迈步和收步。合成动图先展示转身，再展示两人向右跑动，沿用第一关草地、主光和随当前姿态变化的人形投影。

[合成动图](farmer-motion.gif) · [高清 MP4](farmer-motion.mp4)

| 角色 | 转身帧与透明图集 | 跑动帧与透明图集 |
|---|---|---|
| 麦秆帽 | [转身动图](male/turn/animation.gif) · [透明图集](male/turn/sheet-transparent.png) | [跑动动图](male/run/animation.gif) · [透明图集](male/run/sheet-transparent.png) |
| 浅头巾 | [转身动图](female/turn/animation.gif) · [透明图集](female/turn/sheet-transparent.png) | [跑动动图](female/run/animation.gif) · [透明图集](female/run/sheet-transparent.png) |

每格 256×256。每款复用自己的缩放配置。男农民跑动原画的四格统一缩至 88.5% 后进图集，以对齐转身身高。原画、处理用底图、提示词与质检均随动作留档。

四组共 16 张透明帧通过裁边、脚点和比例检查。预览抽查四个转身方向及不同跑动姿态，112 帧 MP4 与 84 帧 GIF 完整解码。本轮为动作和光影预览，游戏内多方向跑动待验证。

## 转身片段的脚底接影（2026-11-27）

两款四向转身按每帧鞋底重新绑定投影，110 个角色帧的两只鞋底均连到身体投影。仍可在同一动图里查看跑动。

[修正版动作 GIF](foot-shadow/farmer-motion.gif) · [高清 MP4](foot-shadow/farmer-motion.mp4)
