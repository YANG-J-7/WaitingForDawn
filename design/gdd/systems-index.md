# 系统索引

> 2026-09-15：当前目标为Steam单机，一局60分钟、每局从零开始；击杀金币与商店抽牌、三卡升星、自由建造、大地图地形与天气以[60分钟战役规则](sixty-minute-campaign-system.md)为当前依据。旧十波系统仅为现有灰盒依据；平台与商业化以[Steam方向调整](../../docs/architecture/change-impact-2026-09-14-steam-single-player.md)为准，微信、广告及在线排行要求暂停。

| 系统 | 文档 | 状态 | 当前验证目标 |
|---|---|---|---|
| 60分钟战役与每局重置 | [sixty-minute-campaign-system.md](sixty-minute-campaign-system.md) | CAM-01方向已确定；未实现 | 细化结束判定、计时与新局边界 |
| 击杀金币、商店抽牌与三卡升星 | [kill-gold-card-shop-fusion-system.md](kill-gold-card-shop-fusion-system.md) | Story-024灰盒实现与自动化通过；待两局自然试玩 | 采集10～15分钟经济数据，再按结果调平 |
| 自由建造、大地图地形与天气 | [sixty-minute-campaign-system.md](sixty-minute-campaign-system.md) | CAM-04/05方向已确定；旧自由建造可复用 | 明确地形可达性、建造条件与天气影响 |
| 历史长流程构思 | [long-session-strategy-direction.md](long-session-strategy-direction.md) | 已被60分钟规则承接 | 仅保留讨论追溯，不按旧候选实施 |
| 旧单夜十波、六卡商店与怪物王 | [single-night-wave-system.md](single-night-wave-system.md) | 旧十波灰盒通过；终局约束已取消；怪物王未实现 | 历史回归依据，不作新版最终验收 |
| 资源建筑持续生产 | [continuous-production-system.md](continuous-production-system.md) | 历史规则：直接每秒到账已由农民运输替代 | 只保留波末不重复给资源、商店不中断生产的约束 |
| 微信激励广告与单局商业化 | [wechat-ad-monetization-system.md](wechat-ad-monetization-system.md) | 历史方案，当前停用 | 不再排期；收费与非广告续战另定 |
| 卡牌经营与昼夜防守核心系统 | [core-loop-system.md](core-loop-system.md) | 0.2 历史基线 | 建筑与伤害初值参考；节奏规则已被单夜十波系统替代 |
| 敌人与建筑克制系统 | [counter-system.md](counter-system.md) | 0.4 箭塔、城墙与守卫对野狼灰盒通过 | 加入野猪与投石怪后继续验证软克制边界 |
| 战斗手牌拖放部署 | [card-drag-placement-system.md](card-drag-placement-system.md) | 跨波手牌、地图拖放与多建筑灰盒通过 | 验证桌面操作与大手牌布局 |
| 兵营守卫与近战拦截 | [barracks-guard-system.md](barracks-guard-system.md) | 0.1 Godot灰盒通过 | 后续验证多敌人压力、岗位取舍与正式移动表现 |
| 自由城墙与战斗商店 | [free-wall-battle-shop-system.md](free-wall-battle-shop-system.md) | 0.1 Godot灰盒通过 | 验证多墙平衡、键鼠交互和实时商店注意力压力 |
| 中心聚落、资源地块与农民运输 | [radial-settlement-logistics-system.md](radial-settlement-logistics-system.md) | Story-015～017与023灰盒验收，PASS WITH RISKS | 已覆盖运输、死亡、地块、人口、多建筑；待完整十波试玩 |

## 后续候选系统

- 本地成绩：累计通过次数、怪物王击杀数、主城剩余耐久、通关时间和彩蛋出现状态待细化。
- 本地存档、暂停恢复、设置与桌面发布验证。
- Steam 成就、云存档、在线排行榜：仅候选，尚未决定接入。
- 每局从零开始，不继承家园、资源、卡牌和星级；局外数值成长不纳入当前方向。
