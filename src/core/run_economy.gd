class_name GlobalRunEconomy
extends Node

signal resources_changed(
	balances: Dictionary,
	current_population: int,
	population_capacity: int
)
signal hunger_changed(is_hungry: bool, hunger_streak: int)

const RESOURCE_IDS: Array[StringName] = [
	&"wood",
	&"food",
	&"stone",
	&"iron",
	&"gold",
]
const INITIAL_BALANCES: Dictionary = {
	&"wood": 140,
	&"food": 32,
	&"stone": 60,
	&"iron": 30,
	&"gold": 20,
}
const INITIAL_POPULATION: int = 6
const INITIAL_POPULATION_CAPACITY: int = 8

var balances: Dictionary = {}
var current_population: int = 0
var population_capacity: int = 0
var is_hungry: bool = false
var hunger_streak: int = 0


func _ready() -> void:
	clear()


func begin_run() -> void:
	balances = INITIAL_BALANCES.duplicate(true)
	current_population = INITIAL_POPULATION
	population_capacity = INITIAL_POPULATION_CAPACITY
	is_hungry = false
	hunger_streak = 0
	_emit_resources_changed()
	hunger_changed.emit(is_hungry, hunger_streak)


func clear() -> void:
	balances.clear()
	for resource_id in RESOURCE_IDS:
		balances[resource_id] = 0
	current_population = 0
	population_capacity = 0
	is_hungry = false
	hunger_streak = 0
	_emit_resources_changed()
	hunger_changed.emit(is_hungry, hunger_streak)


func amount(resource_id: StringName) -> int:
	return int(balances.get(resource_id, 0))


func can_pay(costs: Dictionary) -> bool:
	for resource_id: Variant in costs:
		var cost: int = int(costs[resource_id])
		if cost < 0 or amount(StringName(resource_id)) < cost:
			return false
	return true


func missing_resources(costs: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for resource_id: Variant in costs:
		var typed_id := StringName(resource_id)
		var shortage: int = int(costs[resource_id]) - amount(typed_id)
		if shortage > 0:
			missing[typed_id] = shortage
	return missing


func try_pay(costs: Dictionary) -> bool:
	if not can_pay(costs):
		return false
	for resource_id: Variant in costs:
		var typed_id := StringName(resource_id)
		balances[typed_id] = amount(typed_id) - int(costs[resource_id])
	_emit_resources_changed()
	return true


func add_resource(resource_id: StringName, amount_to_add: int) -> bool:
	if resource_id not in RESOURCE_IDS or amount_to_add < 0:
		return false
	balances[resource_id] = amount(resource_id) + amount_to_add
	_emit_resources_changed()
	return true


func consume_food(required_food: int) -> int:
	if required_food < 0:
		return 0
	var available_food: int = amount(&"food")
	var consumed_food: int = mini(available_food, required_food)
	balances[&"food"] = available_food - consumed_food
	if consumed_food < required_food:
		is_hungry = true
		hunger_streak += 1
	else:
		is_hungry = false
		hunger_streak = 0
	_emit_resources_changed()
	hunger_changed.emit(is_hungry, hunger_streak)
	return consumed_food


func _emit_resources_changed() -> void:
	resources_changed.emit(
		balances.duplicate(true),
		current_population,
		population_capacity
	)
