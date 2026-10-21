extends Node
## 在真实GL主场景上显示实际寻路结果；旧轨迹只作为修复前对照。
const MAIN = preload("res://src/main/main.tscn")
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const Terrain = preload("res://src/gameplay/grid/terrain_map_data.gd")
const Grid = preload("res://src/gameplay/grid/grid_map_model.gd")
const Finder = preload("res://src/gameplay/grid/grid_pathfinder.gd")
const Proof = preload("res://tools/check_mountain_navigation_visuals.gd")
var output := "res://tests/reports/images/s6-stairs-2026-10-20/"
var failures := 0

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			output=argument.trim_prefix("--evidence-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	var main := MAIN.instantiate()
	view.add_child(main)
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	for enemy in main.wave_controller.enemies: enemy.set_physics_process(false)
	main.farmer_manager.set_process(false)
	for frame in range(4): await get_tree().process_frame
	main.notice_seconds=0
	main.notice_panel.hide()
	main.map_camera.zoom=Vector2.ONE*1.5
	main.map_camera.focus_world(Definition.source_to_world(Vector2(1185,410)))
	await capture(view,"s6-clean")
	var low: Vector2 = main.grid_map_model.cell_center(main.grid_map_model.world_to_cell(Definition.source_to_world(Vector2(1105,485))))
	var high: Vector2 = main.grid_map_model.cell_center(main.grid_map_model.world_to_cell(Definition.source_to_world(Vector2(1200,327))))
	var upward: PackedVector2Array = main.grid_pathfinder.find_path(low,high)
	var downward: PackedVector2Array = main.grid_pathfinder.find_path(high,low)
	var proof := Proof.CliffRouteProof.new()
	proof.z_index=90
	proof.caption="S6 上山：两段阶梯 → 平台转弯"
	proof.line_color=Color("73edb5")
	main.add_child(proof)
	# 旧数据存在时导出同镜头实际旧寻路，正常重跑不依赖临时基线文件。
	var baseline := "res://.codex-temp/s6-navigation-before.json"
	if FileAccess.file_exists(baseline):
		var current := Definition.navigation_data()
		Definition._navigation=JSON.parse_string(FileAccess.get_file_as_string(baseline))
		var grid := Grid.new()
		Terrain.apply_to(grid)
		Definition._navigation=current
		for site in Definition.resource_sites(): grid.register_resource_site(StringName(site.id),StringName(site.siteType),Vector2(site.position.x,site.position.y))
		var old_finder := Finder.new(grid)
		var old: PackedVector2Array = old_finder.find_path(low,high)
		proof.path=PackedVector2Array([low])
		proof.path.append_array(old)
		proof.caption="修复前：偏离石梯"
		proof.line_color=Color("ff8278")
		proof.queue_redraw()
		await capture(view,"s6-before-route")
	proof.path=PackedVector2Array([low])
	proof.path.append_array(upward)
	proof.caption="S6 上山：两段阶梯 → 平台转弯"
	proof.line_color=Color("73edb5")
	proof.queue_redraw()
	check(not upward.is_empty() and upward.size()<40,"S6上山使用局部双段石梯通路")
	await capture(view,"s6-uphill-route")
	proof.path=PackedVector2Array([high])
	proof.path.append_array(downward)
	proof.caption="S6 下山：按原阶梯反向通过"
	proof.line_color=Color("ffd661")
	proof.queue_redraw()
	check(not downward.is_empty() and downward.size()<40,"S6下山反向经过原石梯")
	await capture(view,"s6-downhill-route")
	var file := FileAccess.open(output+"s6-paths.json",FileAccess.WRITE)
	var source_up := []
	for point in upward:
		var source: Vector2 = Definition.world_to_source(point)
		source_up.append([source.x,source.y])
	file.store_string(JSON.stringify({"sourceUpward":source_up,"worldUpward":str(upward),"worldDownward":str(downward)},"\t"))
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
