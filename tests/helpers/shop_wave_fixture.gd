extends RefCounted


static func clear_wave(controller: WaveController) -> void:
	# 商店用例验波次衔接而非胜率；经真实死亡/清场信号推进，不改生产数据。
	while controller.spawned_count < controller.active_enemy_count:
		controller._spawn_enemy()
	for enemy in controller.enemies.duplicate():
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.apply_damage(enemy.current_health)
