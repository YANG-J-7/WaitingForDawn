class_name WorldLightEmitter
extends PointLight2D
## 通用暖光组件，跟随父节点；暂停、结算和重开沿用有效游戏时间。
@export var radius: float = 150.0
@export var base_energy: float = 0.48
@export var flicker_amount: float = 0.035
var elapsed: float = 0.0
var system: Node2D
var budget_allowed := true
static var shared_texture: GradientTexture2D

static func light_texture() -> GradientTexture2D:
	if shared_texture == null:
		shared_texture = GradientTexture2D.new()
		shared_texture.width = 256
		shared_texture.height = 256
		shared_texture.fill = GradientTexture2D.FILL_RADIAL
		shared_texture.fill_from = Vector2(0.5,0.5)
		shared_texture.fill_to = Vector2(1.0,0.5)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.18,0.55,1.0])
		gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.76),Color(1,1,1,0.24),Color(1,1,1,0)])
		shared_texture.gradient = gradient
	return shared_texture

func _ready() -> void:
	texture = light_texture()
	texture_scale = radius*2.0/256.0
	color = Color(1.0,0.63,0.29)
	shadow_enabled = false
	RunState.phase_changed.connect(_on_phase_changed)
	_register.call_deferred()

func _register() -> void:
	if not is_inside_tree(): return
	for candidate in get_tree().get_nodes_in_group(&"world_lighting_systems"):
		if candidate.scope != null and candidate.scope.is_ancestor_of(self) and get_canvas() == candidate.get_canvas() and get_viewport() == candidate.get_viewport():
			system = candidate
			system.register_emitter(self)
			return

func _process(delta: float) -> void:
	if RunState.phase in [RunState.Phase.DAY_SETUP, RunState.Phase.WAVE_COMBAT] and not get_tree().paused:
		elapsed += maxf(0.0,delta)
	var dawn: float = system.dawn_blend if is_instance_valid(system) else 0.0
	energy = base_energy * (1.0-dawn*0.7) * (1.0+flicker_amount*sin(elapsed*6.1)+flicker_amount*0.5*sin(elapsed*11.7))
	enabled = budget_allowed and (not is_instance_valid(system) or system.lighting_enabled)

func _on_phase_changed(phase: int) -> void:
	if phase in [RunState.Phase.BOOT,RunState.Phase.DAY_SETUP]: elapsed = 0.0

func _exit_tree() -> void:
	if is_instance_valid(system): system.unregister_emitter(self)
