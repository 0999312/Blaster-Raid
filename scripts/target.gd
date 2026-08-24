class_name AimTrainerTarget
extends StaticBody3D

signal destroyed(target: Node)

var radius := 0.3
var points := 10

var _base_position := Vector3.ZERO
var _move_amplitude := 0.0
var _move_speed := 0.0
var _time := 0.0


func setup(p_radius: float, p_points: int = 10) -> void:
	radius = p_radius
	points = p_points
	_build()


func hit() -> void:
	destroyed.emit(self)
	queue_free()


func _build() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(randf(), 0.65, 0.9)
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.35
	sphere.material = mat
	mesh_instance.mesh = sphere
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)


func _ready() -> void:
	collision_layer = 4
	_base_position = position
	_move_amplitude = randf_range(0.15, 0.45)
	_move_speed = randf_range(1.2, 2.4)
	scale = Vector3.ONE * 0.001
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	position = _base_position + Vector3(0.0, sin(_time * _move_speed) * _move_amplitude, 0.0)
