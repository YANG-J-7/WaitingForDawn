extends Node2D
## 可复用单树场景按边界语义组装；不加载固定整张树林蒙版。
const ART = preload("res://src/gameplay/art/art_visual.gd")
var tree_count := 0

func configure(runtime: RefCounted) -> void:
	y_sort_enabled = true
	var occupied := {}
	for pair in runtime.compiled.cells.forest:
		var cell := Vector2i(pair[0],pair[1])
		# 稳定采样，不因镜头或帧数改变树位；每两格保留错列密林。
		if posmod(cell.x+cell.y,2)!=0: continue
		var key := Vector2i(cell.x/2,cell.y/2)
		if occupied.has(key): continue
		occupied[key]=true
		var tree := ART.new()
		var seed_value := posmod(cell.x*173+cell.y*79,97)
		tree.position = (Vector2(cell)+Vector2(.5,.5))*36+Vector2(float(seed_value%17)-8,0)
		tree.configure("pine_tree",Vector2(90+seed_value%16,132+seed_value%20))
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(tree)
		tree_count+=1
	# 总览的画幅余量由关外自然林带延续；不新增可走区域或资源。
	for row in range(4):
		for index in range(0,100):
			for side in [0,1]:
				if side==1 and index*80>4400: continue
				var tree := ART.new()
				tree.position=Vector2(index*80-400+(row%2)*40,-48-row*90 if side==0 else runtime.bounds.end.y+150+row*90)
				tree.configure("pine_tree",Vector2(104,160))
				tree.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				add_child(tree)
				tree_count+=1
