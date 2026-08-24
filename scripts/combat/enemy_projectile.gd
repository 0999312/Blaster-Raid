class_name EnemyProjectile
extends Area3D
## 敌人投射物：沿方向飞行，命中玩家造成伤害。

var velocity := Vector3.ZERO
var damage := 10.0
var lifetime := 3.0

func setup(p_direction: Vector3, p_damage: float, p_speed: float) -> void:
	velocity = p_direction.normalized() * p_speed
	damage = p_damage

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2  # 命中玩家或墙都会消除
	body_entered.connect(_on_body_entered)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 1.0
	mesh.mesh = sphere
	add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if get_tree().paused:
		return
	if body and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
