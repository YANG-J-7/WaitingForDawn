class_name FarmerManager
extends Node2D

signal roster_changed(active_count: int)
signal delivery_completed(resource_id: StringName, amount: int)
signal worker_lost(job_id: StringName)

var farmers: Array[FarmerAgent] = []
var city_position: Vector2 = Vector2(480.0, 270.0)
var builder: SettlementBuilder
var arrow_tower: ArrowTower
var barracks: Barracks
var current_assignments: Dictionary = {}
var current_job_order: Array[StringName] = []
var next_farmer_index: int = 0


func _process(delta: float) -> void:
	if RunState.phase not in [RunState.Phase.DAY_SETUP, RunState.Phase.WAVE_COMBAT, RunState.Phase.WAVE_RESULT]:
		return
	advance(delta)


func configure(
	home_position: Vector2,
	settlement_builder: SettlementBuilder,
	tower: ArrowTower,
	barracks_building: Barracks
) -> void:
	city_position = home_position
	builder = settlement_builder
	arrow_tower = tower
	barracks = barracks_building


func begin_run(farmer_count: int) -> void:
	reset()
	_sync_roster(farmer_count)


func sync_population(farmer_count: int) -> void:
	_sync_roster(farmer_count)
	apply_assignments(current_assignments, current_job_order)


func apply_assignments(assignments: Dictionary, job_order: Array[StringName]) -> void:
	current_assignments = assignments.duplicate(true)
	current_job_order = job_order.duplicate()
	# 先保留仍有效的原岗位，只有失去岗位的农民参与再分配。
	var remaining: Dictionary = current_assignments.duplicate()
	var available: Array[FarmerAgent] = []
	for farmer in farmers:
		if int(remaining.get(farmer.job_id, 0)) > 0 and farmer.workplace == _workplace_for(farmer.job_id) and is_instance_valid(farmer.workplace):
			remaining[farmer.job_id] = int(remaining[farmer.job_id]) - 1
		else:
			available.append(farmer)
	for job_id in current_job_order:
		var workplace: Node2D = _workplace_for(job_id)
		if workplace == null:
			continue
		var worker_count: int = int(remaining.get(job_id, 0))
		for _worker in range(worker_count):
			if available.is_empty():
				break
			var resource_id: StringName = &""
			var amount_per_trip: int = 0
			if workplace is ResourceBuilding:
				var resource_building := workplace as ResourceBuilding
				if resource_building.definition != null:
					resource_id = resource_building.definition.production_resource
					amount_per_trip = maxi(1, roundi(resource_building.definition.production_per_second))
			var farmer: FarmerAgent = available.pop_front()
			farmer.assign_job(job_id, workplace, resource_id, amount_per_trip)
	for farmer in available:
		farmer.clear_job()


func advance(delta: float) -> void:
	for farmer in farmers:
		if is_instance_valid(farmer):
			farmer.advance(delta)


func reset() -> void:
	for farmer in farmers:
		if is_instance_valid(farmer):
			farmer.queue_free()
	farmers.clear()
	current_assignments.clear()
	current_job_order.clear()
	next_farmer_index = 0
	roster_changed.emit(0)


func active_farmers() -> Array[FarmerAgent]:
	var result: Array[FarmerAgent] = []
	for farmer in farmers:
		if is_instance_valid(farmer) and farmer.current_health > 0:
			result.append(farmer)
	return result


func _sync_roster(farmer_count: int) -> void:
	var target_count: int = maxi(0, farmer_count)
	if target_count == farmers.size():
		return
	while farmers.size() < target_count:
		var farmer := FarmerAgent.new()
		add_child(farmer)
		farmer.configure(next_farmer_index, city_position)
		next_farmer_index += 1
		farmer.delivery_completed.connect(_on_farmer_delivery)
		farmer.died.connect(_on_farmer_died)
		farmers.append(farmer)
	while farmers.size() > target_count:
		var removed: FarmerAgent = farmers.pop_back()
		if is_instance_valid(removed):
			removed.queue_free()
	roster_changed.emit(active_farmers().size())


func _workplace_for(job_id: StringName) -> Node2D:
	if job_id == &"arrow_tower" and arrow_tower != null and arrow_tower.visible:
		return arrow_tower
	if job_id == &"barracks" and barracks != null and barracks.is_built():
		return barracks
	if builder != null:
		for building in builder.placed_buildings():
			if is_instance_valid(building) and building.definition != null and building.definition.card_id == job_id:
				return building
	return null


func _on_farmer_delivery(resource_id: StringName, amount: int) -> void:
	if amount <= 0 or not RunEconomy.add_resource(resource_id, amount):
		return
	delivery_completed.emit(resource_id, amount)


func _on_farmer_died(farmer: FarmerAgent) -> void:
	if farmer not in farmers:
		return
	farmers.erase(farmer)
	current_assignments[farmer.job_id] = maxi(0, int(current_assignments.get(farmer.job_id, 0)) - 1)
	worker_lost.emit(farmer.job_id)
	RunEconomy.lose_population(1)
	roster_changed.emit(active_farmers().size())
	farmer.queue_free()
