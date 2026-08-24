class_name MapBuilder
extends Node3D
## 网格化随机地图生成：房间 + 走廊 + 墙 + 门厅（Kenney prototype 素材）+ 可搜刮点 + 撤离点。

const CELL_SIZE := 4.0
const WALL_HEIGHT := 3.2
const GRID_SIZE := 23
const PROTO_BASE := "res://assets/kenney/prototype/Models/GLB format/"

var _rng := RandomNumberGenerator.new()
var _floor: Array[Array] = []
var _rooms: Array[Rect2i] = []

func build(p_seed: int = 0) -> Dictionary:
	_rng.seed = p_seed
	_floor.clear()
	for x in GRID_SIZE:
		var row: Array = []
		for y in GRID_SIZE:
			row.append(false)
		_floor.append(row)

	var rooms := _generate_rooms()
	if rooms.is_empty():
		# 兜底：中央大房间
		_mark_room(Rect2i(6, 6, 11, 11))
		rooms.append(Rect2i(6, 6, 11, 11))

	_connect_rooms(rooms)
	_build_floor_mesh()
	_build_walls()
	_build_room_decor()
	var data := _collect_spawns(rooms)
	return data

func _generate_rooms() -> Array[Rect2i]:
	var rooms: Array[Rect2i] = []
	var attempts := 0
	while rooms.size() < 6 and attempts < 60:
		attempts += 1
		var w := _rng.randi_range(4, 7)
		var h := _rng.randi_range(4, 7)
		var x := _rng.randi_range(2, GRID_SIZE - w - 2)
		var y := _rng.randi_range(2, GRID_SIZE - h - 2)
		var rect := Rect2i(x, y, w, h)
		var overlaps := false
		for r in rooms:
			if rect.intersects(Rect2i(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2)):
				overlaps = true
				break
		if overlaps:
			continue
		_mark_room(rect)
		rooms.append(rect)
	_rooms = rooms
	return rooms

func _mark_room(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
				_floor[x][y] = true

func _connect_rooms(rooms: Array[Rect2i]) -> void:
	for i in range(1, rooms.size()):
		var a := _room_center(rooms[i - 1])
		var b := _room_center(rooms[i])
		var x := a.x
		var y := a.y
		while x != b.x:
			x += signi(b.x - x)
			if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
				_floor[x][y] = true
		while y != b.y:
			y += signi(b.y - y)
			if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
				_floor[x][y] = true

func _room_center(rect: Rect2i) -> Vector2i:
	return Vector2i(int(rect.position.x + rect.size.x / 2.0), int(rect.position.y + rect.size.y / 2.0))

func _build_floor_mesh() -> void:
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(GRID_SIZE * CELL_SIZE, 0.2, GRID_SIZE * CELL_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.3, 0.33)
	mat.roughness = 0.9
	box.material = mat
	ground.mesh = box
	ground.position = Vector3(GRID_SIZE * CELL_SIZE / 2.0, -0.1, GRID_SIZE * CELL_SIZE / 2.0)
	add_child(ground)

	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCollision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(GRID_SIZE * CELL_SIZE, 0.2, GRID_SIZE * CELL_SIZE)
	collision.shape = shape
	collision.position = Vector3(GRID_SIZE * CELL_SIZE / 2.0, -0.1, GRID_SIZE * CELL_SIZE / 2.0)
	floor_body.add_child(collision)
	add_child(floor_body)

func _build_walls() -> void:
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.28)
	mat.roughness = 0.8
	wall_mesh.material = mat
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if _floor[x][y]:
				continue
			_build_plain_wall(Vector2i(x, y), wall_mesh)

func _build_plain_wall(cell: Vector2i, wall_mesh: BoxMesh) -> void:
	var pos := _cell_to_world(cell)
	var wall := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = wall_mesh
	mesh.position = Vector3(0.0, WALL_HEIGHT / 2.0, 0.0)
	wall.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	collision.shape = shape
	collision.position = mesh.position
	wall.add_child(collision)
	wall.position = pos
	add_child(wall)

## 房间装饰（prototype 素材：立柱/箱体/梯子），在房间内部随机放 0~2 个，作为掩体与点缀。
func _build_room_decor() -> void:
	var decors := ["column.glb", "crate.glb", "ladder.glb"]
	var scales := {"column.glb": Vector3.ONE * 3.2, "crate.glb": Vector3.ONE * 1.5, "ladder.glb": Vector3.ONE * 3.2}
	for i in _rooms.size():
		if i == 0:
			continue  # 出生房不摆
		var r := _rooms[i]
		var count := _rng.randi_range(0, 2)
		for n in count:
			var gx := _rng.randi_range(r.position.x + 1, r.end.x - 2)
			var gy := _rng.randi_range(r.position.y + 1, r.end.y - 2)
			var model_name: String = decors[_rng.randi_range(0, decors.size() - 1)]
			var packed = load(PROTO_BASE + model_name)
			if packed == null or not (packed is PackedScene):
				continue
			var body := StaticBody3D.new()
			body.position = _cell_to_world(Vector2i(gx, gy))
			add_child(body)
			var inst: Node3D = (packed as PackedScene).instantiate() as Node3D
			body.add_child(inst)
			inst.scale = scales[model_name]
			if model_name == "ladder.glb":
				inst.rotation_degrees = Vector3(0.0, _rng.randi_range(0, 3) * 90.0, 0.0)
			# 碰撞按实例化后模型的真实 AABB 生成（column/ladder 模型并非 1×1×1，
			# 旧代码按 scale 立方体放碰撞 → 空气墙 Bug #5.3）。
			# 必须在碰撞父节点（body）空间里测量，把 inst 的缩放/旋转一并算进去。
			var aabb := _collect_model_aabb_in(body, inst)
			if aabb.size.length_squared() > 0.0001:
				var col := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = aabb.size
				col.shape = shape
				col.position = aabb.get_center()
				body.add_child(col)

## 汇总 root 下所有 MeshInstance3D 在 target 局部空间的包围盒（含 root 的缩放/旋转与子节点偏移）。
## target 通常为碰撞体所在父节点（StaticBody3D），保证量出来的尺寸与碰撞体同空间。
func _collect_model_aabb_in(target: Node3D, root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D
		var box := mi.get_aabb()
		var rel := target.global_transform.affine_inverse() * mi.global_transform
		for point in _aabb_corners(box):
			var p := rel * point
			if not found:
				result.position = p
				result.size = Vector3.ZERO
				found = true
			result = result.expand(p)
	return result

func _aabb_corners(box: AABB) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				pts.append(Vector3(x, y, z))
	return pts

func _collect_spawns(rooms: Array[Rect2i]) -> Dictionary:
	var start := Vector3.ZERO
	var extraction := Vector3.ZERO
	if rooms.size() > 0:
		var c := _room_center(rooms[0])
		start = _cell_to_world(c)
		var last := _room_center(rooms[rooms.size() - 1])
		extraction = _cell_to_world(last)

	var enemy_spawns: Array[Vector3] = []
	var container_spawns: Array[Vector3] = []
	var candidate_cells: Array[Vector2i] = []
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if _floor[x][y]:
				var world := _cell_to_world(Vector2i(x, y))
				if world.distance_to(start) < 6.0:
					continue
				candidate_cells.append(Vector2i(x, y))

	for i in range(mini(candidate_cells.size(), 10)):
		var cell = candidate_cells[_rng.randi_range(0, candidate_cells.size() - 1)]
		enemy_spawns.append(_cell_to_world(cell))

	for i in range(mini(candidate_cells.size(), 7)):
		var cell = candidate_cells[_rng.randi_range(0, candidate_cells.size() - 1)]
		var world := _cell_to_world(cell)
		if world.distance_to(start) > 4.0:
			container_spawns.append(world)

	return {
		"start": start + Vector3(0.0, 0.0, 0.0),
		"extraction": extraction + Vector3(0.0, 0.0, 0.0),
		"enemy_spawns": enemy_spawns,
		"container_spawns": container_spawns,
		"grid_size": GRID_SIZE,
		"cell_size": CELL_SIZE,
	}

func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE + CELL_SIZE / 2.0, 0.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)
