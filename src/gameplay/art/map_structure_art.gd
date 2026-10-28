extends Node2D
## 独立生成的崖顶/崖面/坡脚与湖岸结构美术；几何跟随组件，玩法不读取像素。
var cliff_mesh := ArrayMesh.new()
var shore_mesh := ArrayMesh.new()
var shore_views: Array[MeshInstance2D] = []
var cliff_texture: Texture2D
var shore_texture: Texture2D
var cliff_count := 0
var shore_count := 0

func configure(context: RefCounted) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cliff_texture=load("res://assets/map_kits/moonlit_v3/cliff.png")
	shore_texture=load("res://assets/map_kits/moonlit_v3/shore.png")
	var cliffs := _arrays()
	for module in context.modules:
		for pairs in module.payload.get("cliff_polygons",[]):
			var polygon:=PackedVector2Array()
			for pair in pairs: polygon.append(Vector2(pair[0],pair[1])+module.origin)
			_build_cliff(cliffs,polygon)
			cliff_count+=1
		# 先做水面减岛的布尔运算，合并半岛接点，避免两条岸带在交点叠成三角接缝。
		var shores := _arrays()
		var contours: Array[PackedVector2Array] = []
		for pairs in module.payload.get("water_polygons",[]):
			var points := PackedVector2Array()
			for pair in pairs: points.append(Vector2(pair[0],pair[1])+module.origin)
			contours.append(points)
		for pairs in module.payload.get("island_polygons",[]):
			var island := PackedVector2Array()
			for pair in pairs: island.append(Vector2(pair[0],pair[1])+module.origin)
			var clipped: Array[PackedVector2Array] = []
			for contour in contours: clipped.append_array(Geometry2D.clip_polygons(contour,island))
			contours=clipped
		for contour in contours: _build_shore(shores,contour,context)
		if not shores[Mesh.ARRAY_VERTEX].is_empty(): _add_shore_view(shores,module)
	if not cliffs[Mesh.ARRAY_VERTEX].is_empty(): cliff_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cliffs)
	var cliff_view := MeshInstance2D.new()
	cliff_view.name="CliffFaces"
	cliff_view.mesh=cliff_mesh
	cliff_view.show_behind_parent=true
	var skin := ShaderMaterial.new()
	skin.shader=preload("res://src/gameplay/art/cliff_structure.gdshader")
	skin.set_shader_parameter("structure_art",cliff_texture)
	skin.set_shader_parameter("fine_art",load("res://assets/map_kits/moonlit_v2/materials/rock.png"))
	skin.set_shader_parameter("tall_body_art",load("res://assets/map_kits/moonlit_v3/cliff-tall.png"))
	cliff_view.material=skin
	add_child(cliff_view)
	queue_redraw()

func _add_shore_view(arrays: Array,module: Dictionary) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if shore_views.is_empty(): shore_mesh=mesh
	var skin := ShaderMaterial.new()
	skin.shader=preload("res://src/gameplay/art/shore_structure.gdshader")
	skin.set_shader_parameter("shore_art",shore_texture)
	skin.set_shader_parameter("water_control",load("res://"+module.payload.control))
	skin.set_shader_parameter("control_origin",module.origin)
	var size: Array=module.payload.world_size
	skin.set_shader_parameter("control_size",Vector2(size[0],size[1]))
	var view := MeshInstance2D.new()
	view.name="Shore_"+module.instance_id
	view.mesh=mesh
	view.material=skin
	add_child(view)
	shore_views.append(view)

func _build_cliff(arrays: Array,polygon: PackedVector2Array) -> void:
	# 崖顶与坡脚分别沿弧长配对；端面保留真实斜边，避免竖切压成三角拉丝。
	var furthest := 0
	for i in polygon.size():
		if polygon[i].x>polygon[furthest].x: furthest=i
	var edge_index := furthest
	var best := -INF
	for i in range(maxi(1,furthest-2),mini(polygon.size()-1,furthest+2)):
		var edge := polygon[i+1]-polygon[i]
		var score := edge.y-absf(edge.x)*.4
		if score>best:
			best=score
			edge_index=i
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in range(edge_index+1): top.append(polygon[i]+Vector2(0,-16))
	for i in range(polygon.size()-1,edge_index,-1): bottom.append(polygon[i]+Vector2(0,20))
	if top.size()<2 or bottom.size()<2: return
	var length := maxf(_path_length(top),_path_length(bottom))
	var steps := maxi(1,ceili(length/12))
	for i in steps:
		var u0 := float(i)/steps
		var u1 := float(i+1)/steps
		var a := _path_point(top,u0)
		var b := _path_point(top,u1)
		var c := _path_point(bottom,u1)
		var d := _path_point(bottom,u0)
		var h0 := a.distance_to(d)
		var h1 := b.distance_to(c)
		_quad(arrays,PackedVector2Array([a,b,c,d]),PackedVector2Array([Vector2(u0*length/540,0),Vector2(u1*length/540,0),Vector2(u1*length/540,1),Vector2(u0*length/540,1)]),PackedColorArray([Color(h0/512,1,1),Color(h1/512,1,1),Color(h1/512,1,1),Color(h0/512,1,1)]))

func _path_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in points.size()-1: length+=points[i].distance_to(points[i+1])
	return length

func _path_point(points: PackedVector2Array,t: float) -> Vector2:
	var distance := _path_length(points)*t
	for i in points.size()-1:
		var length := points[i].distance_to(points[i+1])
		if distance<=length: return points[i].lerp(points[i+1],distance/maxf(.001,length))
		distance-=length
	return points[-1]

func _build_shore(arrays: Array,points: PackedVector2Array,context: RefCounted) -> void:
	# 轮廓已做布尔差；先确定水面侧，再对尖角作局部小圆角。
	var flip_normal := false
	for i in points.size():
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var tangent := a.direction_to(b)
		var normal := Vector2(-tangent.y,tangent.x)
		var left: bool = context.is_water_point((a+b)*.5+normal*2)
		var right: bool = context.is_water_point((a+b)*.5-normal*2)
		if left!=right:
			flip_normal=left
			break
	var rounded := PackedVector2Array()
	for i in points.size():
		var before := points[(i-1+points.size())%points.size()]
		var corner := points[i]
		var after := points[(i+1)%points.size()]
		var radius := minf(48,minf(corner.distance_to(before),corner.distance_to(after))*.35)
		var start := corner.move_toward(before,radius)
		var finish := corner.move_toward(after,radius)
		for step in 5:
			var t := float(step)/4
			rounded.append(start.lerp(corner,t).lerp(corner.lerp(finish,t),t))
	points=rounded
	# 小圆角由邻近岸石覆盖，碰撞仍读取原轮廓。
	var samples := PackedVector2Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var steps := maxi(1,ceili(a.distance_to(b)/12.0))
		for j in steps: samples.append(a.lerp(b,float(j)/steps))
	points=samples
	var normals := PackedVector2Array()
	var valid: Array[bool] = []
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var tangent: Vector2 = a.direction_to(b)
		var normal := Vector2(-tangent.y,tangent.x)
		if flip_normal: normal=-normal
		normals.append(normal)
		# 与世界外水面相接的边不产生假岸。
		valid.append(not ((a.x>=context.bounds.end.x-26 and b.x>=context.bounds.end.x-26) or (a.y>=context.bounds.end.y-26 and b.y>=context.bounds.end.y-26)))
	var traveled := 28.0
	var piece_index := 0
	for i in points.size():
		if not valid[i]: continue
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var length := a.distance_to(b)
		# 岸石按固定俯视朝向交叠摆放；不把岩石图沿尖角扭成折扇。
		if traveled>=26:
			_shore_piece(arrays,a+normals[i]*3,piece_index%6)
			piece_index+=1
			shore_count+=1
			traveled=0
		traveled+=length

func _shore_piece(arrays: Array,center: Vector2,variant: int) -> void:
	var cuts := [0.0,.17,.83,1.0]
	var alphas := [0.0,1.0,1.0,0.0]
	for i in 3:
		var x0: float = center.x-27+54*cuts[i]
		var x1: float = center.x-27+54*cuts[i+1]
		var u0: float = (variant+cuts[i])/6
		var u1: float = (variant+cuts[i+1])/6
		_quad(arrays,PackedVector2Array([Vector2(x0,center.y-32),Vector2(x1,center.y-32),Vector2(x1,center.y+24),Vector2(x0,center.y+24)]),PackedVector2Array([Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,1)]),PackedColorArray([Color(1,1,1,alphas[i]),Color(1,1,1,alphas[i+1]),Color(1,1,1,alphas[i+1]),Color(1,1,1,alphas[i])]))

func _arrays() -> Array:
	var result:=[]
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX]=PackedVector3Array()
	result[Mesh.ARRAY_TEX_UV]=PackedVector2Array()
	result[Mesh.ARRAY_COLOR]=PackedColorArray()
	result[Mesh.ARRAY_INDEX]=PackedInt32Array()
	return result

func _quad(arrays: Array,points: PackedVector2Array,uvs: PackedVector2Array,colors := PackedColorArray()) -> void:
	var first: int=arrays[Mesh.ARRAY_VERTEX].size()
	for i in 4:
		arrays[Mesh.ARRAY_VERTEX].append(Vector3(points[i].x,points[i].y,0))
		arrays[Mesh.ARRAY_TEX_UV].append(uvs[i])
		arrays[Mesh.ARRAY_COLOR].append(colors[i] if colors.size()==4 else Color.WHITE)
	for i in [0,1,2,0,2,3]: arrays[Mesh.ARRAY_INDEX].append(first+i)

