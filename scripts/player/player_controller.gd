class_name PlayerController
extends CharacterBody3D

const GameSfx = preload("res://scripts/audio/game_sfx.gd")
## 古典 FPS 风格的玩家控制器：高速移动、跳跃、蹲伏、冲刺/闪避。

signal health_changed(current: float, max_value: float)
signal hunger_changed(current: float, max_value: float)
signal inventory_changed
signal weapon_changed(weapon_name: String, mag: int, reserve: int, total_valuable: int)
signal died

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.5
const CROUCH_SPEED := 3.2
const JUMP_VELOCITY := 5.0
const GRAVITY := 9.8
const DASH_SPEED := 15.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.9
const LOOK_MOUSE_SENSITIVITY := 0.003
const LOOK_STICK_SENSITIVITY := 3.2
const PITCH_LIMIT := deg_to_rad(70.0)
const FOOTSTEP_PATHS := [
	"res://assets/kenney/impact-sounds/Audio/footstep_concrete_000.ogg",
	"res://assets/kenney/impact-sounds/Audio/footstep_concrete_001.ogg",
	"res://assets/kenney/impact-sounds/Audio/footstep_concrete_002.ogg",
	"res://assets/kenney/impact-sounds/Audio/footstep_concrete_003.ogg",
	"res://assets/kenney/impact-sounds/Audio/footstep_concrete_004.ogg",
]
const HURT_SOUND_PATH := "res://assets/kenney/impact-sounds/Audio/impactGlass_medium_000.ogg"

var max_health: float = 100.0
var health: float = 100.0
var max_hunger: float = 100.0
var hunger: float = 100.0
var hunger_drain_per_second: float = 1.1
var starvation_damage_per_second: float = 1.5
var move_speed_multiplier: float = 1.0

var actions: Dictionary = {}
var camera: Camera3D
var weapon_controller: WeaponController
var inventory: InventoryController
var survival: SurvivalController
var interaction_area: Area3D
var controls_enabled := false

var _pitch := 0.0
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector3.ZERO
var _crouching := false
var _footstep_streams: Array[AudioStream] = []
var _hurt_stream: AudioStream = null
var _step_timer := 0.0
var _step_index := 0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_build_visual()
	_build_collision()
	_build_camera()
	_build_interaction_area()
	_load_sfx()
	set_physics_process(true)

func setup(p_actions: Dictionary, content_manager: ContentManager, p_max_health: float = 100.0, p_speed_mult: float = 1.0) -> void:
	actions = p_actions
	max_health = p_max_health
	health = max_health
	move_speed_multiplier = p_speed_mult
	inventory = InventoryController.new()
	add_child(inventory)
	survival = SurvivalController.new()
	survival.setup(self, max_hunger, hunger_drain_per_second, starvation_damage_per_second)
	add_child(survival)
	survival.set_active(true)
	weapon_controller = WeaponController.new()
	weapon_controller.setup(self, actions, content_manager)
	add_child(weapon_controller)
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
	inventory_changed.emit()

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_handle_look()
	_handle_movement(delta)
	move_and_slide()
	_update_footsteps(delta)

func _handle_look() -> void:
	var dt := get_physics_process_delta_time()
	# 鼠标：原始像素增量，按 px→rad 直接转（每物理帧一次；配合物理插值渲染平滑）
	var mouse_action: GUIDEAction = actions.get("look_mouse")
	if mouse_action != null:
		var mouse := mouse_action.value_axis_2d
		if mouse.length_squared() > 0.0001:
			rotate_y(-mouse.x * LOOK_MOUSE_SENSITIVITY)
			_pitch -= mouse.y * LOOK_MOUSE_SENSITIVITY
	# 手柄摇杆：模拟值按时间积分
	var stick_action: GUIDEAction = actions.get("look_stick")
	if stick_action != null:
		var stick := stick_action.value_axis_2d
		if stick.length_squared() > 0.0001:
			rotate_y(-stick.x * LOOK_STICK_SENSITIVITY * dt)
			_pitch -= stick.y * LOOK_STICK_SENSITIVITY * dt
	_pitch = clampf(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
	camera.rotation.x = _pitch

func _handle_movement(delta: float) -> void:
	var move_action: GUIDEAction = actions.get("move")
	var sprint_action: GUIDEAction = actions.get("sprint")
	var jump_action: GUIDEAction = actions.get("jump")
	var crouch_action: GUIDEAction = actions.get("crouch")
	var dash_action: GUIDEAction = actions.get("dash")

	var input_dir := Vector2.ZERO
	if move_action:
		input_dir = move_action.value_axis_2d
	input_dir = input_dir.limit_length(1.0)
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	_crouching = crouch_action != null and crouch_action.is_triggered()
	var base_speed := WALK_SPEED
	if _crouching:
		base_speed = CROUCH_SPEED
	elif sprint_action != null and sprint_action.is_triggered():
		base_speed = SPRINT_SPEED
	base_speed *= move_speed_multiplier

	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if dash_action != null and dash_action.is_triggered() and _dash_cooldown <= 0.0:
		_dash_timer = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		_dash_direction = dir if dir.length_squared() > 0.01 else -transform.basis.z
		_dash_direction.y = 0.0
		_dash_direction = _dash_direction.normalized()

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_direction.x * DASH_SPEED
		velocity.z = _dash_direction.z * DASH_SPEED
	else:
		if dir.length_squared() > 0.0:
			var target_velocity := dir * base_speed
			velocity.x = move_toward(velocity.x, target_velocity.x, base_speed * 8.0 * delta)
			velocity.z = move_toward(velocity.z, target_velocity.z, base_speed * 8.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, base_speed * 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, base_speed * 8.0 * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if jump_action != null and jump_action.is_triggered() and is_on_floor():
		velocity.y = JUMP_VELOCITY

func get_crouching() -> bool:
	return _crouching

func heal(amount: float) -> void:
	if health >= max_health:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)

func take_damage(amount: float) -> void:
	if get_tree().paused:
		return
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	_play_hurt_sound()
	if health <= 0.0:
		died.emit()

func eat(hunger_restore: float, health_restore: float) -> void:
	hunger = clampf(hunger + hunger_restore, 0.0, max_hunger)
	heal(health_restore)
	hunger_changed.emit(hunger, max_hunger)

func spend_hunger(delta: float) -> void:
	hunger = maxf(hunger - delta, 0.0)
	hunger_changed.emit(hunger, max_hunger)

func _load_sfx() -> void:
	for path in FOOTSTEP_PATHS:
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStream:
				_footstep_streams.append(stream)
	if ResourceLoader.exists(HURT_SOUND_PATH):
		var res = load(HURT_SOUND_PATH)
		if res is AudioStream:
			_hurt_stream = res

func _update_footsteps(delta: float) -> void:
	if not is_on_floor() or _footstep_streams.is_empty():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 1.0:
		return
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	var interval := clampf(0.55 * WALK_SPEED / maxf(speed, 1.0), 0.25, 0.6)
	_step_timer = interval
	var stream := _footstep_streams[_step_index % _footstep_streams.size()]
	_step_index += 1
	GameSfx.play(stream, randf_range(0.9, 1.1), -10.0)

func _play_hurt_sound() -> void:
	GameSfx.play(_hurt_stream, randf_range(0.95, 1.05), -7.0)

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.5, 0.7)
	body.mesh = capsule
	body.position = Vector3(0.0, 0.9, 0.0)
	body.visible = false  # 第一人称不渲染自身模型，避免遮挡主视角
	add_child(body)

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	collision.shape = shape
	collision.position = Vector3(0.0, 0.9, 0.0)
	add_child(collision)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.55, 0.0)
	camera.current = true
	camera.fov = 85.0
	camera.near = 0.02
	add_child(camera)

func _build_interaction_area() -> void:
	interaction_area = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	shape.shape = sphere
	interaction_area.add_child(shape)
	interaction_area.collision_mask = 16 | 32
	add_child(interaction_area)
