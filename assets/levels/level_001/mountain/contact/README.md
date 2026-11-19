# 山体在前、湖水在后（2026-11-16）

按用户红框要求移除北侧覆盖山壁的旧草石岸，完整山体在前、湖水在后；不重绘、裁短或移动山体。南部原岩石湖岸保留，与独立沙滩素材制作任务无关。

tools/build_mountain_lake_contact.py读取原山体和湖泊输出，生成本目录。上部0～1660世界Y移除旧岸，1660～1780带内衔接南岸；山体轮廓同时排除水域，水格2703。移除上部三处旧岸水花，南侧七处及连续B样条保持。lake-module.json与mountain-module.json由正式组件引用，layout.json指定派生控制图/岸层，主图和小地图同源；新露出的外围山体格保守禁行禁建，九梯路线未改。

重建顺序：按需运行build_level_lake.py、build_level_mountain.py，再运行build_mountain_lake_contact.py，最后Godot导入。原始素材不覆盖，PNG仅作现有素材遮罩处理，没有生成新原画。

227项相关验证通过：衔接9、山体模型46/GL17、湖泊模型7/GL20、地表GL93、制图17、单位寻路18，相关日志无错误。覆盖完整山壁不被旧岸遮挡、水波不移动山体、山后湖面动态、岩壁非水域且禁行禁建、图层顺序、小地图/重开与四画幅。已目检用户区域近景、总览、南岸和小地图；结构/差异检查通过。

实景：本机tests/reports/images/level-mountain/mountain-east-shore-1920.png。独立地表证据：tests/reports/images/mountain-lake-contact/terrain.png。36格边缘、自然走位、完整高度场、主光与长局限制保持，Story-033开放；未提交或推送。
