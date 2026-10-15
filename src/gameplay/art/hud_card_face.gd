extends Control
## 卡面仅负责展示；点击、购买与拖放继续由原按钮校验。
const Icon = preload("res://src/gameplay/art/hud_icon.gd")
var definition: OpeningCardDefinition
var illustration: Texture2D
var shop: bool = false
var star: int = 1
var count: int = 1
var state_text: String = "购买"
var unavailable: bool = false
var highlighted: bool = false
var cost_icons: Array[Control] = []
const PAPER: Texture2D = preload("res://assets/ui/hud_reference_v1/parchment.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	get_parent().mouse_entered.connect(queue_redraw)
	get_parent().mouse_exited.connect(queue_redraw)

func update_icons() -> void:
	for icon in cost_icons:
		remove_child(icon)
		icon.queue_free()
	cost_icons.clear()
	var keys: Array = cost_keys()
	for key in keys:
		var icon := Icon.new()
		icon.kind = str(key)
		add_child(icon)
		cost_icons.append(icon)
	queue_redraw()

func _draw() -> void:
	if definition == null:
		return
	var w: float = size.x
	var h: float = size.y
	var hovered: bool = get_parent().is_hovered() and not unavailable
	var active: bool = highlighted or hovered
	var edge := Color("eebc5c") if active else Color("89704b")
	if active:
		var glow := Icon.box(Color("d6a03c", 0.12), Color("ffe7a0", 0.5), 4)
		glow.set_border_width_all(2)
		draw_style_box(glow, Rect2(-2,-2,w+4,h+4))
	var r := Rect2(1,1,w-2,h-2)
	draw_paper(r,Color.WHITE if not unavailable else Color("b6b5ad"))
	if active:
		draw_style_box(outline(edge),r)
	var font: Font = ThemeDB.fallback_font
	var ink := Color("241c11")
	draw_string(font,Vector2(9,19),definition.display_name,HORIZONTAL_ALIGNMENT_LEFT,w-45,13,ink)
	draw_string(font,Vector2(w-31,19),"★%d" % star,HORIZONTAL_ALIGNMENT_LEFT,28,12,Color("514531"))
	var art_rect: Rect2
	if shop:
		art_rect = Rect2(8,25,w*0.43,h-48)
		draw_string(font,Vector2(w*0.51,43),"持有 %d" % count,HORIZONTAL_ALIGNMENT_LEFT,w*0.48-5,12,ink)
		draw_string(font,Vector2(w*0.51,59),"再差 %d 张可合成" % maxi(0,3-count),HORIZONTAL_ALIGNMENT_LEFT,w*0.48-5,9,Color("5c5548"))
		var button_rect := Rect2(w*0.51,h-30,w*0.46,24)
		draw_style_box(Icon.box(Color("36414b") if unavailable else Color("e8b74e"),Color("746752") if unavailable else Color("ac7c31"),2),button_rect)
		draw_style_box(outline(Color("fff0b7",0.6)),button_rect.grow(-2))
		draw_string(font,button_rect.position+Vector2(0,17),state_text,HORIZONTAL_ALIGNMENT_CENTER,button_rect.size.x,12,Color("e1dfd7") if unavailable else ink)
	else:
		art_rect = Rect2(24,19,w-48,h-42)
		var badge := Rect2(w-30,h-23,23,17)
		draw_style_box(Icon.box(Color("746044"),Color("9d8966"),2),badge)
		draw_string(font,badge.position+Vector2(0,13),"×%d" % count,HORIZONTAL_ALIGNMENT_CENTER,badge.size.x,11,Color("fff3d7"))
	if illustration != null:
		var dims := illustration.get_size()
		var scale_factor: float = minf(art_rect.size.x/dims.x,art_rect.size.y/dims.y)
		var fitted: Vector2 = dims*scale_factor
		draw_texture_rect(illustration,Rect2(art_rect.get_center()-fitted/2,fitted),false)
	var x: float = 8
	var keys: Array = cost_keys()
	for i in range(keys.size()):
		if i >= cost_icons.size():
			break
		cost_icons[i].position = Vector2(x,h-24)
		cost_icons[i].size = Vector2(18,18)
		var amount: int = definition.shop_price if shop else int(definition.build_costs[keys[i]])
		draw_string(font,Vector2(x+20,h-10),str(amount),HORIZONTAL_ALIGNMENT_LEFT,30,14 if shop else 11,ink)
		x += 46

func cost_keys() -> Array:
	if shop:
		return ["gold"]
	var result: Array = []
	for key in [&"wood",&"food",&"stone",&"iron",&"gold"]:
		if definition.build_costs.has(key):
			result.append(key)
	return result

func outline(color: Color) -> StyleBoxFlat:
	var style := Icon.box(Color.TRANSPARENT,color,2)
	style.draw_center = false
	return style

func draw_paper(target: Rect2, tint: Color) -> void:
	# 源边角80像素映射到6逻辑像素；九片独立采样避免切角和边框拉粗。
	var source := Rect2(26,52,1535,888)
	var sx := [source.position.x,source.position.x+80,source.end.x-80,source.end.x]
	var sy := [source.position.y,source.position.y+80,source.end.y-80,source.end.y]
	var dx := [target.position.x,target.position.x+6,target.end.x-6,target.end.x]
	var dy := [target.position.y,target.position.y+6,target.end.y-6,target.end.y]
	for y in range(3):
		for x in range(3):
			draw_texture_rect_region(PAPER,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y]),tint)
