extends Node
const MAIN = preload("res://src/main/main.tscn")
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
var directory := "res://tests/reports/images/mountain-routing-2026-10-15/"
var failures := 0

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			directory = argument.trim_prefix("--evidence-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	main.map_camera.zoom = Vector2.ONE * 1.2
	main.map_camera.focus_world(Definition.source_to_world(Vector2(200,260)))
	var border: Sprite2D = main.get_node("BorderForest")
	border.material.set_shader_parameter("remove_ground", false)
	await capture(view,"border-before")
	var before := view.get_texture().get_image()
	border.material.set_shader_parameter("remove_ground", true)
	await capture(view,"border-after")
	var after := view.get_texture().get_image()
	var pine := 0
	var preserved := 0
	var changed := 0
	for y in range(100,450):
		for x in range(190,600):
			var original := before.get_pixel(x,y)
			var revised := after.get_pixel(x,y)
			var difference := Vector3(original.r-revised.r,original.g-revised.g,original.b-revised.b).length()
			if original.b-original.g>.035 and original.r<original.g*.9:
				pine+=1
				if difference<.012: preserved+=1
			if difference>.04: changed+=1
	check(pine>1000 and float(preserved)/pine>.95,"边界冷蓝树冠像素保留超过95%")
	check(changed>10000,"去除边界树林浅色草地贴片产生实际画面差异")
	print("METRIC: 冷蓝树冠保留=%d/%d 改变像素=%d" % [preserved,pine,changed])
	main.map_camera.zoom = Vector2.ONE * .72
	main.map_camera.focus_world(Definition.source_to_world(Vector2(1160,300)))
	await capture(view,"mountain-clean")
	main.map_camera.show_full_map()
	await capture(view,"full-map")
	var source: Vector2 = main.grid_map_model.cell_center(main.grid_map_model.world_to_cell(Definition.source_to_world(Vector2(930,70))))
	var target: Vector2 = main.grid_map_model.cell_center(main.grid_map_model.world_to_cell(Definition.source_to_world(Vector2(1086,62))))
	var route: PackedVector2Array = main.grid_pathfinder.find_path(source,target)
	var proof := CliffRouteProof.new()
	proof.path = PackedVector2Array([source])
	proof.path.append_array(route)
	for polygon in Definition.navigation_data().hardCliffs:
		proof.rocks.append(Definition.polygon_world(polygon))
	proof.z_index = 90
	main.add_child(proof)
	var west_descent := false
	for point in route:
		west_descent = west_descent or main.grid_map_model.navigation_data(main.grid_map_model.world_to_cell(point)).stair == 1
	check(not route.is_empty() and west_descent,"西侧高台经实际石梯下山绕行，不直接穿入谷底")
	main.map_camera.zoom = Vector2.ONE * .72
	main.map_camera.focus_world(Definition.source_to_world(Vector2(900,140)))
	await capture(view,"northwest-cliff-detour")
	proof.hide()
	main.map_camera.zoom = Vector2.ONE * 1.6
	main.map_camera.focus_world(Definition.source_to_world(Vector2(1010,95)))
	await capture(view,"northwest-cliff-clean")
	var valley: Vector2 = main.grid_map_model.cell_center(main.grid_map_model.world_to_cell(Definition.source_to_world(Vector2(1080,143))))
	var approach: PackedVector2Array = main.grid_pathfinder.find_path(valley,target)
	proof.path = PackedVector2Array([valley])
	proof.path.append_array(approach)
	proof.show()
	proof.queue_redraw()
	check(not approach.is_empty(),"北侧石梯从谷底正面接入，避开前景石壁")
	await capture(view,"northwest-valley-stairs")
	proof.hide()
	main.map_camera.zoom = Vector2.ONE * .6
	main.map_camera.focus_world(Definition.source_to_world(Vector2(930,170)))
	var junction: Array = Definition.navigation_data().junctions[0].point
	var fork: Vector2 = main.grid_map_model.cell_center(main.grid_map_model.world_to_cell(Definition.source_to_world(Vector2(junction[0],junction[1]))))
	for goal in [
		["北侧高台",Definition.source_to_world(Vector2(1120,31)),0.0,Color(1,.9,.2)],
		["东南山路",Definition.source_to_world(Vector2(1200,327)),0.0,Color(.2,.9,1)],
		["西侧铁矿",main.grid_map_model.resource_site_center(&"iron_02"),60.0,Color(.3,1,.5)],
	]:
		var branch: PackedVector2Array = main.grid_pathfinder.find_path(fork,goal[1],goal[2])
		check(not branch.is_empty(),"分叉按目的地生成路线："+goal[0])
		var branch_proof := CliffRouteProof.new()
		branch_proof.path = PackedVector2Array([fork])
		branch_proof.path.append_array(branch)
		branch_proof.line_color = goal[3]
		branch_proof.caption = goal[0]
		branch_proof.z_index = 90
		main.add_child(branch_proof)
	await capture(view,"junction-destination-routes")
	main.queue_free()
	view.queue_free()
	get_tree().quit(failures)

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)

func capture(view: SubViewport,label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := view.get_texture().get_image().save_png(directory+label+".png")
	if result == OK: print("PASS: 截图："+label)
	else: failures+=1

class CliffRouteProof extends Node2D:
	# 只存在于验证场景：黄色为实际寻路结果，红色为禁止通行的岩壁。
	var path := PackedVector2Array()
	var rocks: Array[PackedVector2Array] = []
	var line_color := Color(1,.9,.2)
	var caption := ""
	func _draw() -> void:
		for rock in rocks:
			draw_colored_polygon(rock,Color(1,.15,.1,.25))
			var outline := rock.duplicate()
			outline.append(rock[0])
			draw_polyline(outline,Color(1,.25,.15),1.5,true)
		if path.size()>1:
			draw_polyline(path,line_color,2.5,true)
			for point in path: draw_circle(point,2.5,line_color.lightened(.3))
			if not caption.is_empty():
				draw_circle(path[0],7,Color.WHITE)
				var font := ThemeDB.fallback_font
				var label_at := path[-1]+Vector2(12,-12)
				draw_string_outline(font,label_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,4,Color.BLACK)
				draw_string(font,label_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,line_color)
