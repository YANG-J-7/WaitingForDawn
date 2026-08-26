class_name GlobalRunState
extends Node

signal phase_changed(phase: int)
signal wave_changed(wave_index: int)
signal city_health_changed(current_health: int, maximum_health: int)
signal ad_assistance_changed(is_assisted: bool)

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
const DEFAULT_CITY_HEALTH: int = 600

var run_id: String = ""
var phase: Phase = Phase.BOOT
var current_wave: int = FIRST_WAVE
var city_max_health: int = DEFAULT_CITY_HEALTH
var city_health: int = DEFAULT_CITY_HEALTH
var ad_assisted: bool = false
var ad_continue_used: int = 0


func begin_new_run() -> void:
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), randi()]
	current_wave = FIRST_WAVE
	city_max_health = DEFAULT_CITY_HEALTH
	city_health = DEFAULT_CITY_HEALTH
	ad_assisted = false
	ad_continue_used = 0
	_set_phase(Phase.DAY_SETUP)
	wave_changed.emit(current_wave)
	city_health_changed.emit(city_health, city_max_health)
	ad_assistance_changed.emit(ad_assisted)


func reset_to_boot() -> void:
	run_id = ""
	current_wave = FIRST_WAVE
	city_max_health = DEFAULT_CITY_HEALTH
	city_health = DEFAULT_CITY_HEALTH
	ad_assisted = false
	ad_continue_used = 0
	_set_phase(Phase.BOOT)
	wave_changed.emit(current_wave)
	city_health_changed.emit(city_health, city_max_health)
	ad_assistance_changed.emit(ad_assisted)


func start_current_wave() -> void:
	if phase != Phase.DAY_SETUP and phase != Phase.WAVE_RESULT:
		return
	_set_phase(Phase.WAVE_COMBAT)


func complete_current_wave() -> void:
	if phase != Phase.WAVE_COMBAT:
		return
	if current_wave >= LAST_WAVE:
		_set_phase(Phase.RUN_WON)
		return
	current_wave += 1
	wave_changed.emit(current_wave)
	_set_phase(Phase.WAVE_RESULT)


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
