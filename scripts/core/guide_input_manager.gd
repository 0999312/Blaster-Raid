class_name GuideInputManager
extends Node
## 以代码方式构建 G.U.I.D.E 的 Action / MappingContext，
## 统一支持键鼠与手柄，并负责启用 gameplay 上下文。

var actions: Dictionary = {}
var gameplay_context: GUIDEMappingContext = null
var _guide: Node = null

func _ready() -> void:
	_guide = get_node_or_null("/root/GUIDE")
	if _guide:
		# 暂停时仍要处理输入（Esc/手柄 Start 恢复），GUIDE 保持 ALWAYS
		_guide.process_mode = Node.PROCESS_MODE_ALWAYS
	build()

func is_available() -> bool:
	return _guide != null

func build() -> void:
	if gameplay_context != null:
		return
	gameplay_context = GUIDEMappingContext.new()
	gameplay_context.display_name = "Action Gameplay"

	actions["move"] = _make_action("move", GUIDEAction.GUIDEActionValueType.AXIS_2D)
	actions["look_mouse"] = _make_action("look_mouse", GUIDEAction.GUIDEActionValueType.AXIS_2D)
	actions["look_stick"] = _make_action("look_stick", GUIDEAction.GUIDEActionValueType.AXIS_2D)
	actions["jump"] = _make_action("jump", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["sprint"] = _make_action("sprint", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["crouch"] = _make_action("crouch", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["dash"] = _make_action("dash", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["fire"] = _make_action("fire", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["aim"] = _make_action("aim", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["reload"] = _make_action("reload", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["interact"] = _make_action("interact", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["use_item"] = _make_action("use_item", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["melee"] = _make_action("melee", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["next_weapon"] = _make_action("next_weapon", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["prev_weapon"] = _make_action("prev_weapon", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["inventory"] = _make_action("inventory", GUIDEAction.GUIDEActionValueType.BOOL)
	actions["pause"] = _make_action("pause", GUIDEAction.GUIDEActionValueType.BOOL)

	# 移动
	_bind_axis(actions["move"], "move", KEY_W, KEY_S, KEY_A, KEY_D,
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, true)
	# 视角：鼠标与摇杆拆成两个 action，避免按数值阈值判断来源导致的灵敏度跳变
	_bind_look_mouse(actions["look_mouse"])
	_bind_look_stick(actions["look_stick"])
	# 跳跃
	_bind_button(actions["jump"], "jump", KEY_SPACE, JOY_BUTTON_A)
	_bind_button(actions["sprint"], "sprint", KEY_SHIFT, JOY_BUTTON_LEFT_STICK)
	_bind_button(actions["crouch"], "crouch", KEY_C, JOY_BUTTON_B)
	_bind_button(actions["dash"], "dash", KEY_ALT, JOY_BUTTON_RIGHT_STICK)
	# 射击/瞄准
	_bind_mouse_button(actions["fire"], MOUSE_BUTTON_LEFT, JOY_BUTTON_RIGHT_SHOULDER)
	_bind_mouse_button(actions["aim"], MOUSE_BUTTON_RIGHT, JOY_BUTTON_LEFT_SHOULDER)
	# 换弹/交互/道具/近战
	_bind_button(actions["reload"], "reload", KEY_R, JOY_BUTTON_X)
	_bind_button(actions["interact"], "interact", KEY_E, JOY_BUTTON_Y)
	_bind_button(actions["use_item"], "use_item", KEY_F, JOY_BUTTON_LEFT_SHOULDER)
	_bind_button(actions["melee"], "melee", KEY_V, JOY_BUTTON_RIGHT_STICK)
	# 切枪
	_bind_button(actions["next_weapon"], "next_weapon", KEY_2, JOY_BUTTON_DPAD_RIGHT)
	_bind_button(actions["prev_weapon"], "prev_weapon", KEY_1, JOY_BUTTON_DPAD_LEFT)
	# 菜单
	_bind_button(actions["inventory"], "inventory", KEY_TAB, JOY_BUTTON_BACK)
	_bind_button(actions["pause"], "pause", KEY_ESCAPE, JOY_BUTTON_START)

	# 把 action mapping 加进 context
	for action in actions.values():
		var mapping := GUIDEActionMapping.new()
		mapping.action = action
		mapping.input_mappings = action.get_meta("input_mappings", [])
		gameplay_context.mappings.append(mapping)

func enable_gameplay() -> void:
	if _guide == null:
		return
	_guide.call("enable_mapping_context", gameplay_context)

func disable_gameplay() -> void:
	if _guide == null:
		return
	if _guide.call("is_mapping_context_enabled", gameplay_context):
		_guide.call("disable_mapping_context", gameplay_context)

func get_action(name: String) -> GUIDEAction:
	return actions.get(name, null)

func _make_action(action_name: String, value_type: int) -> GUIDEAction:
	var a := GUIDEAction.new()
	a.name = action_name
	a.action_value_type = value_type
	a.is_remappable = true
	a.display_name = action_name
	return a

func _bind_axis(action: GUIDEAction, _name: String, key_up: Key, key_down: Key, key_left: Key, key_right: Key,
		joy_x: JoyAxis, joy_y: JoyAxis, invert_y: bool) -> void:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action

	var key_mappings: Array[GUIDEInputMapping] = []
	if key_left != KEY_NONE:
		var im := GUIDEInputMapping.new()
		im.input = _make_key(key_left)
		im.triggers = [_make_down()]
		im.modifiers = [_scale_modifier(Vector3(-1.0, 0.0, 0.0))]
		key_mappings.append(im)
	if key_right != KEY_NONE:
		var im := GUIDEInputMapping.new()
		im.input = _make_key(key_right)
		im.triggers = [_make_down()]
		im.modifiers = [_scale_modifier(Vector3(1.0, 0.0, 0.0))]
		key_mappings.append(im)
	if key_up != KEY_NONE:
		var im := GUIDEInputMapping.new()
		im.input = _make_key(key_up)
		im.triggers = [_make_down()]
		im.modifiers = [_swizzle_modifier(), _scale_modifier(Vector3(0.0, -1.0, 0.0))]
		key_mappings.append(im)
	if key_down != KEY_NONE:
		var im := GUIDEInputMapping.new()
		im.input = _make_key(key_down)
		im.triggers = [_make_down()]
		im.modifiers = [_swizzle_modifier(), _scale_modifier(Vector3(0.0, 1.0, 0.0))]
		key_mappings.append(im)

	var joy := GUIDEInputJoyAxis2D.new()
	joy.x = joy_x
	joy.y = joy_y
	var im_joy := GUIDEInputMapping.new()
	im_joy.input = joy
	im_joy.triggers = [_make_down()]
	key_mappings.append(im_joy)

	mapping.input_mappings = key_mappings
	action.set_meta("input_mappings", mapping.input_mappings)

func _bind_look_mouse(action: GUIDEAction) -> void:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var inputs: Array[GUIDEInputMapping] = []

	var mouse := GUIDEInputMouseAxis2D.new()
	var im_mouse := GUIDEInputMapping.new()
	im_mouse.input = mouse
	im_mouse.triggers = [_make_down()]
	inputs.append(im_mouse)

	mapping.input_mappings = inputs
	action.set_meta("input_mappings", mapping.input_mappings)

func _bind_look_stick(action: GUIDEAction) -> void:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var inputs: Array[GUIDEInputMapping] = []

	var joy := GUIDEInputJoyAxis2D.new()
	joy.x = JOY_AXIS_RIGHT_X
	joy.y = JOY_AXIS_RIGHT_Y
	var im_joy := GUIDEInputMapping.new()
	im_joy.input = joy
	im_joy.triggers = [_make_down()]
	inputs.append(im_joy)

	mapping.input_mappings = inputs
	action.set_meta("input_mappings", mapping.input_mappings)

func _bind_button(action: GUIDEAction, _name: String, key: Key, joy_button: JoyButton) -> void:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var inputs: Array[GUIDEInputMapping] = []

	var im_key := GUIDEInputMapping.new()
	im_key.input = _make_key(key)
	im_key.triggers = [_make_pressed()]
	inputs.append(im_key)

	var im_joy := GUIDEInputMapping.new()
	im_joy.input = _make_joy_button(joy_button)
	im_joy.triggers = [_make_pressed()]
	inputs.append(im_joy)

	mapping.input_mappings = inputs
	action.set_meta("input_mappings", mapping.input_mappings)

func _bind_mouse_button(action: GUIDEAction, mouse_button: MouseButton, joy_button: JoyButton) -> void:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var inputs: Array[GUIDEInputMapping] = []

	var im_mouse := GUIDEInputMapping.new()
	var mouse := GUIDEInputMouseButton.new()
	mouse.button = mouse_button
	im_mouse.input = mouse
	im_mouse.triggers = [_make_down()]
	inputs.append(im_mouse)

	var im_joy := GUIDEInputMapping.new()
	im_joy.input = _make_joy_button(joy_button)
	im_joy.triggers = [_make_down()]
	inputs.append(im_joy)

	mapping.input_mappings = inputs
	action.set_meta("input_mappings", mapping.input_mappings)

func _make_key(key: Key) -> GUIDEInputKey:
	var k := GUIDEInputKey.new()
	k.key = key
	return k

func _make_joy_button(button: JoyButton) -> GUIDEInputJoyButton:
	var b := GUIDEInputJoyButton.new()
	b.button = button
	return b

func _make_pressed() -> GUIDETriggerPressed:
	return GUIDETriggerPressed.new()

func _make_down() -> GUIDETriggerDown:
	return GUIDETriggerDown.new()

func _scale_modifier(scale: Vector3) -> GUIDEModifierScale:
	var m := GUIDEModifierScale.new()
	m.scale = scale
	return m

func _swizzle_modifier() -> GUIDEModifierInputSwizzle:
	return GUIDEModifierInputSwizzle.new()
