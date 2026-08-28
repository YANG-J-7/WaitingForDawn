class_name WaveEconomy
extends Node

signal workers_assigned(assigned_population: int, idle_population: int)
signal settlement_completed(wave_index: int, report: Dictionary)
signal jobs_changed(job_order: Array[StringName])
signal assignments_changed(
	worker_assignments: Dictionary,
	assigned_population: int,
	idle_population: int,
	is_locked: bool
)

var settled_waves: Array[int] = []
var assigned_population: int = 0
var idle_population: int = 0
var arrow_tower_workers: int = 0
var last_report: Dictionary = {}
var last_summary: String = ""
var job_order: Array[StringName] = []
var job_capacities: Dictionary = {}
var job_labels: Dictionary = {}
var worker_assignments: Dictionary = {}
var assignments_locked: bool = false
var user_modified_assignments: bool = false


func refresh_jobs(builder: SettlementBuilder, arrow_tower: ArrowTower) -> void:
	var next_order: Array[StringName] = []
	var next_capacities: Dictionary = {}
	var next_labels: Dictionary = {}
	if arrow_tower.visible:
		next_order.append(&"arrow_tower")
		next_capacities[&"arrow_tower"] = 1
		next_labels[&"arrow_tower"] = "箭塔"
	for building in builder.placed_buildings():
		if not is_instance_valid(building) or building.definition == null:
			continue
		var job_id: StringName = building.definition.card_id
		next_order.append(job_id)
		next_capacities[job_id] = building.definition.worker_slots
		next_labels[job_id] = building.definition.display_name

	var roster_changed: bool = next_order != job_order
	var next_assignments: Dictionary = {}
	for job_id in next_order:
		next_assignments[job_id] = mini(
			int(worker_assignments.get(job_id, 0)),
			int(next_capacities[job_id])
		)
	job_order = next_order
	job_capacities = next_capacities
	job_labels = next_labels
	worker_assignments = next_assignments
	if user_modified_assignments:
		_recalculate_totals()
	else:
		_apply_auto_distribution()
	if roster_changed:
		jobs_changed.emit(job_order.duplicate())
	_emit_assignments_changed()


func adjust_workers(job_id: StringName, delta: int) -> bool:
	if assignments_locked or job_id not in job_capacities or delta == 0:
		return false
	var current: int = int(worker_assignments.get(job_id, 0))
	var next: int = current + delta
	if next < 0 or next > int(job_capacities[job_id]):
		return false
	if delta > 0 and assigned_population + delta > RunEconomy.current_population:
		return false
	worker_assignments[job_id] = next
	user_modified_assignments = true
	_recalculate_totals()
	_emit_assignments_changed()
	return true


func auto_assign_workers() -> bool:
	if assignments_locked:
		return false
	user_modified_assignments = true
	_apply_auto_distribution()
	_emit_assignments_changed()
	return true


func prepare_wave(builder: SettlementBuilder, arrow_tower: ArrowTower) -> void:
	refresh_jobs(builder, arrow_tower)
	assignments_locked = true
	arrow_tower_workers = int(worker_assignments.get(&"arrow_tower", 0))
	arrow_tower.enabled = arrow_tower.visible and arrow_tower_workers > 0
	for building in builder.placed_buildings():
		building.assign_workers(int(worker_assignments.get(building.definition.card_id, 0)))
	workers_assigned.emit(assigned_population, idle_population)
	_emit_assignments_changed()


func unlock_for_planning() -> void:
	assignments_locked = false
	_emit_assignments_changed()


func settle_wave(wave_index: int, builder: SettlementBuilder) -> bool:
	if wave_index in settled_waves:
		return false

	var production: Dictionary = {}
	for building in builder.placed_buildings():
		if not is_instance_valid(building) or building.definition == null:
			continue
		var definition: OpeningCardDefinition = building.definition
		if definition.worker_slots <= 0 or definition.production_resource.is_empty():
			continue
		var produced: int = floori(
			float(definition.production_per_wave * building.assigned_workers)
			/ float(definition.worker_slots)
		)
		if produced <= 0:
			continue
		production[definition.production_resource] = (
			int(production.get(definition.production_resource, 0)) + produced
		)

	for resource_id: Variant in production:
		RunEconomy.add_resource(StringName(resource_id), int(production[resource_id]))

	var required_food: int = RunEconomy.current_population
	var consumed_food: int = RunEconomy.consume_food(required_food)
	settled_waves.append(wave_index)
	last_report = {
		"production": production.duplicate(true),
		"food_required": required_food,
		"food_consumed": consumed_food,
		"is_hungry": RunEconomy.is_hungry,
		"assigned_population": assigned_population,
		"idle_population": idle_population,
	}
	last_summary = _format_summary(last_report)
	settlement_completed.emit(wave_index, last_report.duplicate(true))
	return true


func reset(builder: SettlementBuilder) -> void:
	settled_waves.clear()
	assigned_population = 0
	idle_population = 0
	arrow_tower_workers = 0
	last_report.clear()
	last_summary = ""
	job_order.clear()
	job_capacities.clear()
	job_labels.clear()
	worker_assignments.clear()
	assignments_locked = false
	user_modified_assignments = false
	for building in builder.placed_buildings():
		if is_instance_valid(building):
			building.assign_workers(0)
	jobs_changed.emit(job_order.duplicate())
	_emit_assignments_changed()


func job_label(job_id: StringName) -> String:
	return str(job_labels.get(job_id, job_id))


func job_capacity(job_id: StringName) -> int:
	return int(job_capacities.get(job_id, 0))


func assigned_workers_for(job_id: StringName) -> int:
	return int(worker_assignments.get(job_id, 0))


func _apply_auto_distribution() -> void:
	var available_population: int = RunEconomy.current_population
	for job_id in job_order:
		var assigned: int = mini(int(job_capacities[job_id]), available_population)
		worker_assignments[job_id] = assigned
		available_population -= assigned
	_recalculate_totals()


func _recalculate_totals() -> void:
	assigned_population = 0
	for job_id in job_order:
		assigned_population += int(worker_assignments.get(job_id, 0))
	idle_population = maxi(0, RunEconomy.current_population - assigned_population)


func _emit_assignments_changed() -> void:
	assignments_changed.emit(
		worker_assignments.duplicate(true),
		assigned_population,
		idle_population,
		assignments_locked
	)


func _format_summary(report: Dictionary) -> String:
	var parts: Array[String] = []
	var names: Dictionary = {
		&"wood": "木",
		&"food": "食",
		&"stone": "石",
		&"iron": "铁",
		&"gold": "金",
	}
	var production: Dictionary = report["production"]
	for resource_id in RunEconomy.RESOURCE_IDS:
		var produced: int = int(production.get(resource_id, 0))
		if produced > 0:
			parts.append("+%d%s" % [produced, names[resource_id]])
	var production_text: String = "无生产" if parts.is_empty() else " ".join(parts)
	var hunger_text: String = "，发生饥饿" if bool(report["is_hungry"]) else ""
	return "生产%s；消耗%d/%d食；岗位%d/%d（空闲%d）%s" % [
		production_text,
		int(report["food_consumed"]),
		int(report["food_required"]),
		int(report["assigned_population"]),
		RunEconomy.current_population,
		int(report["idle_population"]),
		hunger_text,
	]
