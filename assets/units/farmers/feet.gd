extends RefCounted

# 图集内坐标。上排为四个站姿，下排为四帧跑步。
const POSES := {
	&"male": {
		"standing_height": 168.75,
		"feet": [
			[Vector2(117, 234), Vector2(154, 223)],
			[Vector2(107, 217), Vector2(139, 234)],
			[Vector2(124, 234), Vector2(152, 219)],
			[Vector2(104, 217), Vector2(127, 234)],
			[Vector2(172, 234)],
			[Vector2(135, 234)],
			[Vector2(177, 234)],
			[Vector2(135, 234)],
		],
	},
	&"female": {
		"standing_height": 173.0,
		"feet": [
			[Vector2(116, 234), Vector2(148, 226)],
			[Vector2(102, 226), Vector2(134, 234)],
			[Vector2(119, 234), Vector2(149, 227)],
			[Vector2(108, 225), Vector2(132, 234)],
			[Vector2(171, 234)],
			[Vector2(132, 234)],
			[Vector2(175, 234)],
			[Vector2(133, 234)],
		],
	},
}
