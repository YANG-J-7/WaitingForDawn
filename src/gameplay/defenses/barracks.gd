class_name Barracks
extends Node2D

signal guard_roster_changed(active_count: int, assigned_workers: int)
signal destroyed(barracks: Barracks)

const GUARD_SCENE: PackedScene = preload("res://src/gameplay/defenses/barracks_guard.tscn")

@export var guard_definition: GuardDefinition
@export var maximum_health: int = 260
@export var armor: int = 10

var card_definition: OpeningCardDefinition
var current_health: int = 0
var active: bool = false
var assigned_workers: int = 0
var guards: Array[BarracksGuard] = []
var deployed_guard_slots: int = 0


func _ready() -> void:
	RunState.phase_changed.connect(_on_phase_changed)
	queue_redraw()


func build(card: OpeningCardDefinition) -> bool:
	if card == null or card.card_id != &"barracks" or is_built():
		return false
	card_definition = card
	current_health = maximum_health
	active = true
	visible = true
	if RunState.phase == RunState.Phase.WAVE_COMBAT:
		_sync_guard_count()
	queue_redraw()
	return true


func is_built() -> bool:
	return active and current_health > 0


func is_attackable() -> bool:
	return is_built()


func attackable_radius() -> float:
	return 42.0


func apply_enemy_attack(base_damage: int, _enemy_id: StringName) -> int:
	if not is_built() or base_damage <= 0:
		return 0
	var final_damage: int = maxi(1, floori(float(base_damage) * 100.0 / (100.0 + float(armor))))
	var applied: int = mini(current_health, final_damage)
	current_health -= applied
	if current_health == 0:
		active = false
		visible = false
		_clear_guards()
		destroyed.emit(self)
	queue_redraw()
	return applied


func set_assigned_workers(worker_count: int) -> void:
	assigned_workers = clampi(worker_count, 0, 2)
	if is_built() and RunState.phase == RunState.Phase.WAVE_COMBAT:
		_sync_guard_count()
	guard_roster_changed.emit(active_guards().size(), assigned_workers)


func active_guards() -> Array[BarracksGuard]:
	var result: Array[BarracksGuard] = []
	for guard in guards:
		if is_instance_valid(guard) and guard.is_active():
			result.append(guard)
	return result


func available_guard() -> BarracksGuard:
	for guard in active_guards():
		if guard.is_available():
			return guard
	return null


func reset() -> void:
	_clear_guards()
	card_definition = null
	current_health = 0
	active = false
	assigned_workers = 0
	deployed_guard_slots = 0
	visible = false
	guard_roster_changed.emit(0, 0)
	queue_redraw()


func _sync_guard_count() -> void:
	if guard_definition == null:
		return
	var living_guards: Array[BarracksGuard] = active_guards()
	while living_guards.size() > assigned_workers:
		living_guards.back().dismiss()
		living_guards = active_guards()
	deployed_guard_slots = mini(deployed_guard_slots, assigned_workers)
	while deployed_guard_slots < assigned_workers:
		_spawn_guard(deployed_guard_slots)
		deployed_guard_slots += 1
		living_guards = active_guards()
	guard_roster_changed.emit(living_guards.size(), assigned_workers)


func _spawn_guard(guard_index: int) -> void:
	var guard: BarracksGuard = GUARD_SCENE.instantiate() as BarracksGuard
	add_child(guard)
	guard.position = Vector2(10.0, 48.0 + guard_index * 30.0)
	guard.configure(guard_definition, guard_index)
	guard.defeated.connect(_on_guard_defeated)
	guard.target_released.connect(_on_guard_target_released)
	guards.append(guard)


func _clear_guards() -> void:
	var previous_guards: Array[BarracksGuard] = guards.duplicate()
	guards.clear()
	for guard in previous_guards:
		if not is_instance_valid(guard):
			continue
		guard.dismiss()
		guard.queue_free()


func _on_guard_defeated(guard: BarracksGuard) -> void:
	guards.erase(guard)
	guard_roster_changed.emit(active_guards().size(), assigned_workers)
	guard.queue_free()


func _on_guard_target_released(_guard: BarracksGuard) -> void:
	guard_roster_changed.emit(active_guards().size(), assigned_workers)


func _on_phase_changed(phase: int) -> void:
	if phase == RunState.Phase.WAVE_COMBAT:
		_clear_guards()
		deployed_guard_slots = 0
		if is_built():
			_sync_guard_count()
	elif phase in [RunState.Phase.WAVE_RESULT, RunState.Phase.RUN_LOST, RunState.Phase.RUN_WON]:
		_clear_guards()
		deployed_guard_slots = 0
		guard_roster_changed.emit(0, assigned_workers)


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(-28.0, -22.0, 56.0, 44.0), Color("765b43"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34.0, -22.0),
		Vector2(0.0, -44.0),
		Vector2(34.0, -22.0),
	]), Color("9b604d"))
	draw_rect(Rect2(-8.0, 2.0, 16.0, 20.0), Color("2e3038"))
	draw_string(ThemeDB.fallback_font, Vector2(-22.0, 39.0), "兵营", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var health_ratio: float = float(current_health) / float(maximum_health)
	draw_rect(Rect2(-28, -52, 56, 4), Color("2b1d25"))
	draw_rect(Rect2(-28, -52, 56 * health_ratio, 4), Color("7ecf75"))
