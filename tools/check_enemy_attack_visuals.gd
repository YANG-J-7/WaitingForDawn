extends Node
## 真实主场景下记录进城路线、沿途拦截及目标失效后的接力。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const Proof = preload("res://tools/check_mountain_navigation_visuals.gd")
var output := "res://tests/reports/images/enemy-routes-2026-10-20/"
var failures := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := SubViewport.new()
	view.size=Vector2i(1280,720)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	var main := preload("res://src/main/main.tscn").instantiate()
	view.add_child(main)
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	main.wave_controller.reset_wave()
	main.farmer_manager.set_process(false)
	main.notice_seconds=0
	main.notice_panel.hide()
	var controller: WaveController=main.wave_controller
	controller.set_world_targets([])
	var start: Vector2=main.grid_pathfinder.spawn_position(Definition.source_to_world(Vector2(1200,327)))
	controller.spawn_points=[start]
	controller.start_first_wave()
	controller._spawn_enemy()
	controller.spawning=false
	var enemy: EnemyActor=controller.enemies[0]
	enemy.set_physics_process(false)
	var route: PackedVector2Array=enemy.path_follower.path.duplicate()
	check(route.size()>14,"山区野狼出生即有进城路线")
	if route.size()<=14:
		get_tree().quit(1)
		return
	var near := FarmerAgent.new()
	controller.add_child(near)
	near.configure(0,controller.city_target_position)
	near.global_position=route[5]
	var far := FarmerAgent.new()
	controller.add_child(far)
	far.configure(1,controller.city_target_position)
	far.global_position=route[12]
	var baseline := Proof.CliffRouteProof.new()
	baseline.path=PackedVector2Array([start])
	baseline.path.append_array(route)
	baseline.caption="进城路线"
	baseline.line_color=Color("73edb5")
	baseline.z_index=90
	main.add_child(baseline)
	var attack := Proof.CliffRouteProof.new()
	attack.z_index=91
	attack.line_color=Color("ffd661")
	main.add_child(attack)
	main.map_camera.zoom=Vector2.ONE*.9
	main.map_camera.focus_world((start+far.global_position)/2)
	await capture(view,"spawn-city-route")
	controller.set_world_targets([far,near])
	check(enemy.world_target==near,"实景优先最近沿途农民")
	attack.path=PackedVector2Array([enemy.global_position])
	attack.path.append_array(enemy.attack_approach(near))
	attack.caption="先攻击最近农民"
	attack.queue_redraw()
	await capture(view,"nearest-interception")
	var city_health := RunState.city_health
	for step in range(1200):
		controller._assign_defensive_targets()
		enemy._physics_process(.05)
		if near.current_health<near.maximum_health: break
	check(near.current_health<near.maximum_health and RunState.city_health==city_health,"山区野狼实际攻击农民，未直接越过目标伤城")
	await capture(view,"attacking-nearest")
	near.apply_enemy_attack(999,&"wolf")
	controller._assign_defensive_targets()
	check(enemy.world_target==far,"农民死亡后实景接力下一目标")
	attack.path=PackedVector2Array([enemy.global_position])
	attack.path.append_array(enemy.attack_approach(far))
	attack.caption="接力下一目标"
	attack.queue_redraw()
	await capture(view,"next-route-target")
	main.queue_free()
	view.queue_free()
	get_tree().quit(failures)

func check(value: bool,label: String) -> void:
	if value: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)

func capture(view: SubViewport,label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(view.get_texture().get_image().save_png(output+label+".png")==OK,"截图："+label)
