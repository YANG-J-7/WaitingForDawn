extends Node2D
## 明确路线上的石阶原生几何，皮肤复用生成岩面；不从场景概念图剪物件。
var stair_mesh := ArrayMesh.new()
var texture: Texture2D
var tread_count := 0

func configure(context: RefCounted) -> void:
	texture = load("res://assets/map_kits/moonlit_v2/materials/rock.png")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for module in context.modules:
		for route in module.payload.get("paths",[]):
			if route.kind != "stair": continue
			var points := PackedVector2Array()
			for pair in route.points: points.append(Vector2(pair[0],pair[1])+module.origin)
			var carried := 0.0
			for index in range(points.size()-1):
				var a := points[index]
				var b := points[index+1]
				var length := a.distance_to(b)
				var tangent := a.direction_to(b)
				var normal := Vector2(-tangent.y,tangent.x)
				var distance := carried
				while distance < length:
					var center := a+tangent*distance
					var lower_a := center-normal*31-tangent*4.6
					var lower_b := center+normal*31-tangent*4.6
					var quad := PackedVector2Array([lower_a,lower_b,center+normal*31+tangent*4.6,center-normal*31+tangent*4.6])
					_append_quad(vertices,uv,colors,indices,quad,Color(.9,.96,1.0))
					_append_quad(vertices,uv,colors,indices,PackedVector2Array([lower_a+Vector2(0,3),lower_b+Vector2(0,3),lower_b,lower_a]),Color(.35,.42,.50))
					tread_count+=1
					distance+=9.0
				carried=distance-length
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	if not vertices.is_empty(): stair_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	queue_redraw()

func _append_quad(vertices: PackedVector3Array,uv: PackedVector2Array,colors: PackedColorArray,indices: PackedInt32Array,points: PackedVector2Array,color: Color) -> void:
	var first := vertices.size()
	for point in points:
		vertices.append(Vector3(point.x,point.y,0))
		uv.append(point/156.0)
		colors.append(color)
	for i in [0,1,2,0,2,3]: indices.append(first+i)

func _draw() -> void:
	if texture != null and stair_mesh.get_surface_count()>0: draw_mesh(stair_mesh,texture)
