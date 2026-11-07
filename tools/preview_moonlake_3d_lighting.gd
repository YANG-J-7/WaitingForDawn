extends Node3D

const Playable = preload("res://tools/preview_moonlake_3d_playable.gd")
const ArtStage = preload("res://tools/moonlake_3d_art/stage.gd")

const PREVIEW_SPEED := 60.0

@onready var sample: Playable = $Playable
@onready var art: ArtStage = $ArtStage
@onready var timeline: HSlider = $HUD/Panel/Rows/Timeline
@onready var time_label: Label = $HUD/Panel/Rows/Time
@onready var pause_button: Button = $HUD/Panel/Rows/Playback/Pause
@onready var light_select: OptionButton = $HUD/Panel/Rows/Light
@onready var shadow_select: OptionButton = $HUD/Panel/Rows/Shadow

var elapsed := 0.0
var motion_seconds := 0.0
var playback_paused := false
var tree_grid_revision := -1
var tree_drag_active := false


func _ready() -> void:
	$Playable/Graybox/HUD/Panel/Text/Title.text = "月湖山谷 · 3D 光影样区"
	art.configure(sample)
	timeline.max_value = RunState.CAMPAIGN_DURATION_SECONDS
	timeline.value_changed.connect(set_elapsed)
	pause_button.toggled.connect(set_playback_paused)
	$HUD/Panel/Rows/Playback/Reset.pressed.connect(reset_time)
	light_select.add_item("主光 · 方向光")
	light_select.add_item("主光 · 北缘移动点光")
	light_select.item_selected.connect(set_light_mode)
	shadow_select.add_item("阴影 · 全关")
	shadow_select.add_item("阴影 · 山崖与树林")
	shadow_select.add_item("阴影 · 加入建筑和单位")
	shadow_select.item_selected.connect(set_shadow_mode)
	$HUD/Panel/Rows/Brazier.toggled.connect(art.set_brazier_visible)
	set_elapsed(0.0)


func _process(delta: float) -> void:
	if not playback_paused:
		motion_seconds += delta
		set_elapsed(elapsed + delta * PREVIEW_SPEED)
	var dragging := get_viewport().gui_is_dragging()
	if sample.world.grid.revision != tree_grid_revision or dragging or tree_drag_active:
		art.refresh_tree_visibility()
		tree_grid_revision = sample.world.grid.revision
		tree_drag_active = dragging


func set_elapsed(value: float) -> void:
	elapsed = clampf(value, 0.0, RunState.CAMPAIGN_DURATION_SECONDS)
	art.set_time(elapsed, motion_seconds)
	timeline.set_value_no_signal(elapsed)
	var seconds := floori(elapsed)
	var period := "黎明" if elapsed >= RunState.CAMPAIGN_DURATION_SECONDS - 300.0 else "月夜"
	time_label.text = "已用 %02d:%02d · %s" % [seconds / 60, seconds % 60, period]


func set_playback_paused(value: bool) -> void:
	playback_paused = value
	sample.simulation_paused = value
	pause_button.set_pressed_no_signal(value)
	pause_button.text = "继续 ×60" if value else "暂停"


func set_light_mode(mode: int) -> void:
	light_select.select(mode)
	art.set_light_mode(mode)


func set_shadow_mode(mode: int) -> void:
	shadow_select.select(mode)
	art.set_shadow_mode(mode)


func reset_time() -> void:
	motion_seconds = 0.0
	set_elapsed(0.0)
