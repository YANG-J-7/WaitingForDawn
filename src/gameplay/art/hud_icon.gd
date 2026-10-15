extends Control
## 共享透明图集；区域取自源图主体检查，不重新压缩或烘焙文字。
const SOURCE: Texture2D = preload("res://assets/ui/hud_reference_v1/icons.png")
const REGIONS := {
	"wood": Rect2(46,90,293,259),
	"food": Rect2(423,76,236,267),
	"stone": Rect2(758,96,283,246),
	"iron": Rect2(1112,113,291,220),
	"gold": Rect2(46,424,304,233),
	"population": Rect2(400,442,303,205),
	"moon": Rect2(782,412,240,254),
	"threat": Rect2(1123,399,274,273),
	"city": Rect2(82,728,224,280),
	"coins": Rect2(400,749,292,250),
	"refresh": Rect2(778,740,245,255),
	"star": Rect2(1124,734,273,261),
}
static var textures: Dictionary = {}
var kind: String = "wood"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)

func _draw() -> void:
	var texture: Texture2D = icon_texture(kind)
	var dimensions: Vector2 = texture.get_size()
	var fitted: Vector2 = dimensions * minf(size.x/dimensions.x,size.y/dimensions.y)
	draw_texture_rect(texture,Rect2((size-fitted)/2,fitted),false)

static func icon_texture(id: String) -> Texture2D:
	if not textures.has(id):
		var texture := AtlasTexture.new()
		texture.atlas = SOURCE
		texture.region = REGIONS.get(id,REGIONS["wood"])
		texture.filter_clip = true
		textures[id] = texture
	return textures[id]

static func box(fill: Color, edge: Color, radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
