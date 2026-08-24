class_name AimTrainerPlayer
extends CharacterBody3D

signal shot_fired(result: Dictionary)

const MOUSE_SENSITIVITY := 0.002
const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const HEAD_HEIGHT := 1.6
const RAY_LENGTH := 200.0

var camera: Camera3D
var raycast: RayCast3D
var gun_mesh: MeshInstance3D
var controls_enabled := true
var _pitch := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_build_collision()
	_build_camera()
	_build_raycast()
	_build_gun()
	set_controls_enabled(true)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		camera.rotation.x = _pitch
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
				and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_fire()


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector3.ZERO
		return

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction.length_squared() > 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


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
	camera.position = Vector3(0.0, HEAD_HEIGHT, 0.0)
	camera.current = true
	camera.fov = 75.0
	add_child(camera)


func _build_raycast() -> void:
	raycast = RayCast3D.new()
	raycast.position = Vector3.ZERO
	raycast.target_position = Vector3(0.0, 0.0, -RAY_LENGTH)
	raycast.collision_mask = 1 | 4
	raycast.collide_with_areas = true
	camera.add_child(raycast)


func _build_gun() -> void:
	gun_mesh = MeshInstance3D.new()
	var gun_box := BoxMesh.new()
	gun_box.size = Vector3(0.08, 0.12, 0.45)
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.18, 0.19, 0.21)
	gun_mat.roughness = 0.55
	gun_box.material = gun_mat
	gun_mesh.mesh = gun_box
	gun_mesh.position = Vector3(0.28, -0.22, -0.35)
	camera.add_child(gun_mesh)


func _fire() -> void:
	raycast.force_raycast_update()
	var result := {
		"hit": false,
		"target": null,
		"position": Vector3.ZERO,
		"normal": Vector3.ZERO,
	}
	if raycast.is_colliding():
		result["hit"] = true
		result["position"] = raycast.get_collision_point()
		result["normal"] = raycast.get_collision_normal()
		result["target"] = raycast.get_collider()
	shot_fired.emit(result)
