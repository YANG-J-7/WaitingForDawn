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
		tree.position = (Vector2(cell)+Vector2(.5,.5))*36+Vector2(float(seed_value%31)-15,float(posmod(seed_value*19,47))-23)
		tree.configure("pine_tree",Vector2(78+seed_value%45,128+seed_value%69))
		tree.modulate=Color(.87+float(seed_value%11)/100,.91+float(seed_value%7)/100,1)
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
	_dress_highlands(runtime)

func _dress_highlands(runtime: RefCounted) -> void:
	# 仅在原有不可通行山台布景；离路径两格以上，不新增树障碍或资源。
	var forbidden := {}
	for entry in runtime.navigation.cells:
		var cell := Vector2i(entry.cell[0],entry.cell[1])
		for y in range(-2,3):
			for x in range(-2,3): forbidden[cell+Vector2i(x,y)]=true
	for kind in ["cliff","water"]:
		for pair in runtime.compiled.cells[kind]:
			var cell := Vector2i(pair[0],pair[1])
			for y in range(-1,2):
				for x in range(-1,2): forbidden[cell+Vector2i(x,y)]=true
	for pair in runtime.navigation.mountainCells:
		var cell := Vector2i(pair[0],pair[1])
		var seed_value := posmod(cell.x*173+cell.y*79,997)
		if seed_value%37!=0 or forbidden.has(cell): continue
		var point := (Vector2(cell)+Vector2(.5,.5))*36
		var near_resource := false
		for site in runtime.compiled.resourceSites:
			if point.distance_to(Vector2(site.position.x,site.position.y))<180: near_resource=true
		if near_resource: continue
		var tree := ART.new()
		tree.position=point
		tree.configure("pine_tree",Vector2(78+seed_value%25,128+seed_value%49))
		tree.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(tree)
		tree_count+=1
