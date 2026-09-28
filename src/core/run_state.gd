class_name GlobalRunState
extends Node

signal phase_changed(phase: int)
signal wave_changed(wave_index: int)
signal city_health_changed(current_health: int, maximum_health: int)
signal ad_assistance_changed(is_assisted: bool)
signal campaign_time_changed(remaining_seconds: float)
signal threat_stage_changed(stage_index: int)

enum Phase {
	BOOT,
	DAY_SETUP,
	WAVE_COMBAT,
	WAVE_RESULT,
	RUN_WON,
	RUN_LOST,
}

const FIRST_WAVE: int = 1
const LAST_WAVE: int = 10
const CAMPAIGN_DURATION_SECONDS: float = 60.0 * 60.0
const THREAT_STAGE_SECONDS: float = 10.0 * 60.0
const LAST_THREAT_STAGE: int = 6
const DEFAULT_CITY_HEALTH: int = 600
const DEFAULT_CITY_ARMOR: int = 10

var run_id: String = ""
var phase: Phase = Phase.BOOT
var current_wave: int = FIRST_WAVE
var city_max_health: int = DEFAULT_CITY_HEALTH
var city_health: int = DEFAULT_CITY_HEALTH
var city_armor: int = DEFAULT_CITY_ARMOR
var ad_assisted: bool = false
var ad_continue_used: int = 0
var campaign_elapsed_seconds: float = 0.0
var threat_stage: int = 1
var timeout_generation: int = 0


func begin_new_run() -> void:
	timeout_generation += 1
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), randi()]
	current_wave = FIRST_WAVE
	city_max_health = DEFAULT_CITY_HEALTH
	city_health = DEFAULT_CITY_HEALTH
	city_armor = DEFAULT_CITY_ARMOR
	ad_assisted = false
	ad_continue_used = 0
	campaign_elapsed_seconds = 0.0
	threat_stage = 1
	_set_phase(Phase.DAY_SETUP)
	wave_changed.emit(current_wave)
	city_health_changed.emit(city_health, city_max_health)
	ad_assistance_changed.emit(ad_assisted)
	campaign_time_changed.emit(campaign_remaining_seconds())
	threat_stage_changed.emit(threat_stage)


func reset_to_boot() -> void:
	timeout_generation += 1
	run_id = ""
	current_wave = FIRST_WAVE
	city_max_health = DEFAULT_CITY_HEALTH
	city_health = DEFAULT_CITY_HEALTH
	city_armor = DEFAULT_CITY_ARMOR
	ad_assisted = false
	ad_continue_used = 0
	campaign_elapsed_seconds = 0.0
	threat_stage = 1
	_set_phase(Phase.BOOT)
	wave_changed.emit(current_wave)
	city_health_changed.emit(city_health, city_max_health)
	ad_assistance_changed.emit(ad_assisted)
	campaign_time_changed.emit(campaign_remaining_seconds())
	threat_stage_changed.emit(threat_stage)


func start_current_wave() -> void:
	if phase != Phase.DAY_SETUP and phase != Phase.WAVE_RESULT:
		return
	_set_phase(Phase.WAVE_COMBAT)


func complete_current_wave() -> void:
	if phase != Phase.WAVE_COMBAT:
		return
	current_wave += 1
	wave_changed.emit(current_wave)
	_set_phase(Phase.WAVE_RESULT)


func advance_campaign_time(delta: float) -> void:
	if phase != Phase.WAVE_COMBAT or delta <= 0.0 or get_tree().paused:
		return
	campaign_elapsed_seconds = minf(CAMPAIGN_DURATION_SECONDS, campaign_elapsed_seconds + delta)
	var next_stage: int = mini(
		LAST_THREAT_STAGE,
		int(floor(campaign_elapsed_seconds / THREAT_STAGE_SECONDS)) + 1
	)
	if next_stage != threat_stage:
		threat_stage = next_stage
		threat_stage_changed.emit(threat_stage)
	campaign_time_changed.emit(campaign_remaining_seconds())
	if campaign_elapsed_seconds >= CAMPAIGN_DURATION_SECONDS:
		var generation: int = timeout_generation
		_resolve_campaign_timeout.call_deferred(generation)


func campaign_remaining_seconds() -> float:
	return maxf(0.0, CAMPAIGN_DURATION_SECONDS - campaign_elapsed_seconds)


func _resolve_campaign_timeout(generation: int) -> void:
	if generation != timeout_generation:
		return
	if phase != Phase.WAVE_COMBAT or city_health <= 0:
		return
	_set_phase(Phase.RUN_WON)


func damage_city(amount: int) -> void:
	if phase != Phase.WAVE_COMBAT or amount <= 0:
		return
	city_health = maxi(0, city_health - amount)
	city_health_changed.emit(city_health, city_max_health)
	if city_health == 0:
		_set_phase(Phase.RUN_LOST)


func mark_ad_continue_used() -> bool:
	if ad_continue_used >= 1:
		return false
	ad_continue_used = 1
	ad_assisted = true
	ad_assistance_changed.emit(ad_assisted)
	return true


func phase_name() -> String:
	return str(Phase.keys()[phase])


func _set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	phase_changed.emit(phase)
