extends Node2D
## 小型岩块仅修饰已有结构边缘，不产生资源或修改碰撞。
const ART = preload("res://src/gameplay/art/art_visual.gd")
var count := 0

func configure(context: RefCounted,grid: RefCounted) -> void:
	for module in context.modules:
		for polygon in module.payload.get("cliff_polygons",[]):
			for index in range(polygon.size()):
				var a: Vector2=Vector2(polygon[index][0],polygon[index][1])+module.origin
				var next: Array=polygon[(index+1)%polygon.size()]
				var b: Vector2=Vector2(next[0],next[1])+module.origin
				if b.x>=a.x: continue
				var length:=a.distance_to(b)
				for step in range(int(length/58)):
					var point:=a.lerp(b,(step+.5)/maxf(1,int(length/58)))+Vector2(0,-8)
					var cell: Vector2i=grid.world_to_cell(point)
					if not grid.is_inside(cell) or grid.cell_data(cell).terrain_type!=&"cliff": continue
					var rock:=ART.new()
					rock.position=point
					rock.configure("boulder",Vector2(24+posmod(step,3)*5,19+posmod(step,3)*3))
					rock.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					rock.modulate=Color(.65,.72,.83)
					add_child(rock)
					count+=1
