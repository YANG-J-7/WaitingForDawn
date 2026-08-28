class_name OpeningCardDefinition
extends Resource

@export var card_id: StringName = &"card"
@export var display_name: String = "建筑"
@export_enum("resource", "defense") var category: String = "resource"
@export_range(0, 999, 1) var shop_price: int = 6
@export var build_costs: Dictionary = {}
@export var build_cost_text: String = "待实现"
@export var production_resource: StringName = &""
@export_range(0, 999, 1) var production_per_wave: int = 0
@export_range(0, 8, 1) var worker_slots: int = 0
@export var building_color: Color = Color("6b8f5e")
@export_multiline var description: String = ""


func category_label() -> String:
	return "资源" if category == "resource" else "防御"
