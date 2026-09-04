class_name OpeningCardDefinition
extends Resource

@export var card_id: StringName = &"card"
@export var display_name: String = "建筑"
@export_enum("resource", "defense", "population") var category: String = "resource"
@export_range(0, 999, 1) var shop_price: int = 6
@export var build_costs: Dictionary = {}
@export var build_cost_text: String = "待实现"
@export var production_resource: StringName = &""
@export_range(0.0, 100.0, 0.1) var production_per_second: float = 0.0
@export_range(0, 8, 1) var worker_slots: int = 0
@export var required_resource_site: StringName = &""
@export_range(0, 8, 1) var population_capacity_bonus: int = 0
@export_range(12.0, 64.0, 1.0) var footprint_radius: float = 34.0
@export_range(1, 2000, 1) var maximum_health: int = 180
@export_range(0, 100, 1) var armor: int = 5
@export var building_color: Color = Color("6b8f5e")
@export_multiline var description: String = ""


func category_label() -> String:
	match category:
		"resource":
			return "资源"
		"population":
			return "人口"
		_:
			return "防御"
