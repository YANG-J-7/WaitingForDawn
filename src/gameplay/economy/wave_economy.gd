class_name WaveEconomy
extends Node

signal workers_assigned(assigned_population: int, idle_population: int)
signal settlement_completed(wave_index: int, report: Dictionary)
signal production_tick(produced_resources: Dictionary)
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
var production_builder: SettlementBuilder
var production_arrow_tower: ArrowTower
var production_barracks: Barracks
var production_progress: Dictionary = {}
var total_continuous_production: Dictionary = {}


func _process(delta: float) -> void:
	advance_production(delta)


func refresh_jobs(
	builder: SettlementBuilder,
	arrow_tower: ArrowTower,
	barracks: Barracks = null
) -> void:
	production_builder = builder
	production_arrow_tower = arrow_tower
	production_barracks = barracks
	var next_order: Array[StringName] = []
	var next_capacities: Dictionary = {}
	var next_labels: Dictionary = {}
	if arrow_tower.visible:
		next_order.append(&"arrow_tower")
		next_capacities[&"arrow_tower"] = 1
		next_labels[&"arrow_tower"] = "箭塔"
	if barracks != null and barracks.is_built():
		next_order.append(&"barracks")
		next_capacities[&"barracks"] = 2
		next_labels[&"barracks"] = "兵营"
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
	_apply_assignments_to_entities()
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
	_apply_assignments_to_entities()
	_emit_assignments_changed()
	return true


func auto_assign_workers() -> bool:
	if assignments_locked:
		return false
	user_modified_assignments = true
	_apply_auto_distribution()
	_apply_assignments_to_entities()
	_emit_assignments_changed()
	return true


func prepare_wave(
	builder: SettlementBuilder,
	arrow_tower: ArrowTower,
	barracks: Barracks = null
) -> void:
	refresh_jobs(builder, arrow_tower, barracks)
	assignments_locked = true
	_apply_assignments_to_entities()
	workers_assigned.emit(assigned_population, idle_population)
	_emit_assignments_changed()


func unlock_for_planning() -> void:
	assignments_locked = false
	_emit_assignments_changed()


func settle_wave(wave_index: int, _builder: SettlementBuilder) -> bool:
	if wave_index in settled_waves:
		return false

	var required_food: int = RunEconomy.current_population
	var consumed_food: int = RunEconomy.consume_food(required_food)
	settled_waves.append(wave_index)
	last_report = {
		"production": {},
		"continuous_production": total_continuous_production.duplicate(true),
		"food_required": required_food,
		"food_consumed": consumed_food,
		"is_hungry": RunEconomy.is_hungry,
		"assigned_population": assigned_population,
		"idle_population": idle_population,
	}
	last_summary = _format_summary(last_report)
	settlement_completed.emit(wave_index, last_report.duplicate(true))
	return true


func advance_production(delta: float) -> Dictionary:
	var produced_resources: Dictionary = {}
	if delta <= 0.0 or production_builder == null:
		return produced_resources
	if RunState.phase not in [
		RunState.Phase.DAY_SETUP,
		RunState.Phase.WAVE_COMBAT,
		RunState.Phase.WAVE_RESULT,
	]:
		return produced_resources
	for building in production_builder.placed_buildings():
		if not is_instance_valid(building) or building.definition == null:
			continue
		var definition: OpeningCardDefinition = building.definition
		if (
			definition.production_resource.is_empty()
			or definition.production_per_second <= 0.0
			or definition.worker_slots <= 0
		):
			continue
		var workers: int = int(worker_assignments.get(definition.card_id, 0))
		if workers <= 0:
			continue
		var building_key: int = building.get_instance_id()
		var rate: float = (
			definition.production_per_second
			* float(workers)
			/ float(definition.worker_slots)
		)
		var progress: float = float(production_progress.get(building_key, 0.0)) + rate * delta
		var payout: int = floori(progress + 0.000001)
		production_progress[building_key] = progress - float(payout)
		if payout <= 0:
			continue
		var resource_id: StringName = definition.production_resource
		produced_resources[resource_id] = int(produced_resources.get(resource_id, 0)) + payout

	for resource_id: Variant in produced_resources:
		var typed_resource_id := StringName(resource_id)
		var amount: int = int(produced_resources[resource_id])
		RunEconomy.add_resource(typed_resource_id, amount)
		total_continuous_production[typed_resource_id] = (
			int(total_continuous_production.get(typed_resource_id, 0)) + amount
		)
	if not produced_resources.is_empty():
		production_tick.emit(produced_resources.duplicate(true))
	return produced_resources


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
	production_progress.clear()
	total_continuous_production.clear()
	production_builder = null
	production_arrow_tower = null
	if production_barracks != null and is_instance_valid(production_barracks):
		production_barracks.set_assigned_workers(0)
	production_barracks = null
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


func _apply_assignments_to_entities() -> void:
	if production_arrow_tower != null and is_instance_valid(production_arrow_tower):
		arrow_tower_workers = int(worker_assignments.get(&"arrow_tower", 0))
		production_arrow_tower.enabled = production_arrow_tower.visible and arrow_tower_workers > 0
	if production_barracks != null and is_instance_valid(production_barracks):
		production_barracks.set_assigned_workers(int(worker_assignments.get(&"barracks", 0)))
	if production_builder == null:
		return
	for building in production_builder.placed_buildings():
		if is_instance_valid(building) and building.definition != null:
			building.assign_workers(int(worker_assignments.get(building.definition.card_id, 0)))


func _emit_assignments_changed() -> void:
	assignments_changed.emit(
		worker_assignments.duplicate(true),
		assigned_population,
		idle_population,
		assignments_locked
	)


func _format_summary(report: Dictionary) -> String:
	var hunger_text: String = "，发生饥饿" if bool(report["is_hungry"]) else ""
	return "资源建筑持续生产中；波末消耗%d/%d食；岗位%d/%d（空闲%d）%s" % [
		int(report["food_consumed"]),
		int(report["food_required"]),
		int(report["assigned_population"]),
		RunEconomy.current_population,
		int(report["idle_population"]),
		hunger_text,
	]
