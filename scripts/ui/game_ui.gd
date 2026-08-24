class_name GameUI
extends CanvasLayer

const GameSfx = preload("res://scripts/audio/game_sfx.gd")
## 主菜单、HUD、整备/改枪、结算与暂停界面（代码构建）。

signal start_pressed
signal gunsmith_pressed
signal resume_pressed
signal back_to_menu_pressed
signal weapon_selected(weapon_id: String)
signal attachment_selected(attachment_id: String)
signal upgrade_chosen(index: int)
signal upgrade_purchase_requested(upgrade_id: String)

const FONT := preload("res://assets/fonts/MiSans-Semibold.ttf")
const UI_CLICK_PATH := "res://addons/kenney_interface_sounds/click_001.wav"

var root: Control
var hud_root: Control
var menu_panel: PanelContainer
var gunsmith_panel: PanelContainer
var result_panel: PanelContainer
var pause_panel: PanelContainer
var upgrade_panel: PanelContainer

var health_label: Label
var hunger_label: Label
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var ammo_label: Label
var weapon_label: Label
var loot_label: Label
var extraction_label: Label
var hint_label: Label
var crosshair: Control
var extraction_bar: ProgressBar
var items_label: Label
var toast_label: Label
var _toast_tween: Tween = null

var gunsmith_title: Label
var weapons_box: VBoxContainer
var attachments_box: VBoxContainer
var gunsmith_status: Label

var _selected_weapon_id := ""
var _current_weapons: Array[WeaponData] = []
var _current_attachments: Array[String] = []
var upgrade_box: VBoxContainer
var result_title: Label
var result_stats: Label
var upgrades_box: VBoxContainer
var _current_upgrades: Array[UpgradeData] = []
var _current_levels: Dictionary = {}
var _ui_click_stream: AudioStream = null

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load_ui_sfx()
	_wire_all_buttons()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hud_build()
	_menu_build()
	_gunsmith_build()
	_result_build()
	_pause_build()
	_upgrade_build()
	show_menu_ui()

# ── HUD ────────────────────────────────────────────
func _hud_build() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_root)

	crosshair = _make_crosshair()
	hud_root.add_child(crosshair)

	var top_left := MarginContainer.new()
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.offset_left = 18
	top_left.offset_top = 14
	top_left.offset_right = 360
	top_left.offset_bottom = 90
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top_left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	top_left.add_child(box)
	health_label = _make_label("生命 100")
	hunger_label = _make_label("饱食 100")
	box.add_child(health_label)
	health_bar = _make_progress_bar()
	box.add_child(health_bar)
	box.add_child(hunger_label)
	hunger_bar = _make_progress_bar()
	box.add_child(hunger_bar)

	var top_right := MarginContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -420
	top_right.offset_top = 14
	top_right.offset_right = -18
	top_right.offset_bottom = 90
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top_right)
	var box2 := VBoxContainer.new()
	box2.add_theme_constant_override("separation", 4)
	box2.alignment = BoxContainer.ALIGNMENT_END
	top_right.add_child(box2)
	weapon_label = _make_label("武器")
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label = _make_label("弹药")
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box2.add_child(weapon_label)
	box2.add_child(ammo_label)

	var bottom := MarginContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 18
	bottom.offset_top = -100
	bottom.offset_right = 620
	bottom.offset_bottom = -18
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom)
	var box3 := VBoxContainer.new()
	box3.add_theme_constant_override("separation", 4)
	bottom.add_child(box3)
	loot_label = _make_label("战利品价值 0")
	extraction_label = _make_label("")
	box3.add_child(loot_label)
	box3.add_child(extraction_label)
	items_label = _make_label("背包：空")
	items_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.6))
	box3.add_child(items_label)

	extraction_bar = ProgressBar.new()
	extraction_bar.custom_minimum_size = Vector2(260, 12)
	extraction_bar.show_percentage = false
	extraction_bar.visible = false
	hud_root.add_child(extraction_bar)
	extraction_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	extraction_bar.offset_left = -130
	extraction_bar.offset_right = 130
	extraction_bar.offset_top = -42
	extraction_bar.offset_bottom = -30

	hint_label = _make_label("E 搜刮 | F 使用 | R 换弹 | 1/2 切枪")
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.offset_left = -520
	hint_label.offset_top = -40
	hint_label.offset_right = -18
	hint_label.offset_bottom = -14
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_root.add_child(hint_label)

	toast_label = _make_label("")
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -300
	toast_label.offset_right = 300
	toast_label.offset_top = -84
	toast_label.offset_bottom = -56
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.modulate = Color(1, 1, 1, 0)
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud_root.add_child(toast_label)

## 底部中央短暂提示（拾取/使用道具反馈）。
func show_toast(text: String) -> void:
	if toast_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.text = text
	toast_label.modulate = Color(1, 1, 1, 0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.45)

func _make_crosshair() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): 
		var center := c.get_viewport_rect().size / 2.0
		var color := Color(1,1,1,0.9)
		c.draw_rect(Rect2(center.x - 1, center.y - 12, 2, 8), color)
		c.draw_rect(Rect2(center.x - 1, center.y + 4, 2, 8), color)
		c.draw_rect(Rect2(center.x - 12, center.y - 1, 8, 2), color)
		c.draw_rect(Rect2(center.x + 4, center.y - 1, 8, 2), color)
	)
	return c

# ── Menus ──────────────────────────────────────────
func _menu_build() -> void:
	menu_panel = _make_center_panel()
	root.add_child(menu_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	menu_panel.add_child(box)
	var title := _make_label("BLASTER RAID")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	var sub := _make_label("古典 FPS × 搜打撤 × Roguelite\n搜索物资 · 清剿敌人 · 活着撤离")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	var start := Button.new()
	start.text = "开始行动"
	start.custom_minimum_size = Vector2(260, 0)
	start.pressed.connect(func(): start_pressed.emit())
	box.add_child(start)
	var gunsmith := Button.new()
	gunsmith.text = "枪匠整备 / 改枪"
	gunsmith.custom_minimum_size = Vector2(260, 0)
	gunsmith.pressed.connect(func(): gunsmith_pressed.emit())
	box.add_child(gunsmith)
	var credits_label := _make_label("")
	credits_label.name = "CreditsLabel"
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credits_label)
	var controls := _make_label("键鼠：WASD 移动 · 鼠标视角 · 左键射击 · Shift 冲刺 · C 蹲 · Alt 闪避\n手柄：左摇杆移动 · 右摇杆视角 · RT 射击 · A 跳跃 · Y 交互")
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(controls)

func _gunsmith_build() -> void:
	gunsmith_panel = _make_center_panel()
	gunsmith_panel.visible = false
	root.add_child(gunsmith_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	gunsmith_panel.add_child(box)
	gunsmith_title = _make_label("枪匠整备")
	gunsmith_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gunsmith_title.add_theme_font_size_override("font_size", 32)
	box.add_child(gunsmith_title)
	weapons_box = VBoxContainer.new()
	box.add_child(weapons_box)
	var sep := HSeparator.new()
	box.add_child(sep)
	var att_label := _make_label("可用配件：")
	box.add_child(att_label)
	attachments_box = VBoxContainer.new()
	box.add_child(attachments_box)
	gunsmith_status = _make_label("")
	gunsmith_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(gunsmith_status)
	var sep2 := HSeparator.new()
	box.add_child(sep2)
	var upgrade_title := _make_label("永久强化：")
	box.add_child(upgrade_title)
	upgrades_box = VBoxContainer.new()
	box.add_child(upgrades_box)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(200, 0)
	back.pressed.connect(func(): back_to_menu_pressed.emit())
	box.add_child(back)

func _result_build() -> void:
	result_panel = _make_center_panel()
	result_panel.visible = false
	root.add_child(result_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	result_panel.add_child(box)
	var title := _make_label("撤离结果")
	title.name = "ResultTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	result_title = title
	var stats := _make_label("")
	stats.name = "ResultStats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	result_stats = stats
	var again := Button.new()
	again.text = "再次行动"
	again.custom_minimum_size = Vector2(240, 0)
	again.pressed.connect(func(): start_pressed.emit())
	box.add_child(again)
	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(240, 0)
	menu_btn.pressed.connect(func(): back_to_menu_pressed.emit())
	box.add_child(menu_btn)

func _pause_build() -> void:
	pause_panel = _make_center_panel()
	pause_panel.visible = false
	root.add_child(pause_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(box)
	var title := _make_label("已暂停")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var resume := Button.new()
	resume.text = "继续"
	resume.custom_minimum_size = Vector2(220, 0)
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)
	var quit := Button.new()
	quit.text = "返回主菜单"
	quit.custom_minimum_size = Vector2(220, 0)
	quit.pressed.connect(func(): back_to_menu_pressed.emit())
	box.add_child(quit)

func _upgrade_build() -> void:
	upgrade_panel = _make_center_panel()
	upgrade_panel.visible = false
	root.add_child(upgrade_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	upgrade_panel.add_child(box)
	upgrade_box = box
	var title := _make_label("精英战利品：选择强化")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

func show_upgrade_choices(choices: Array[Dictionary]) -> void:
	# 清空旧的强化按钮（保留标题即可）
	var box := upgrade_box
	if box == null:
		return
	for child in box.get_children():
		if child is Button:
			child.queue_free()
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "%s\n%s" % [ch.get("name", "强化"), ch.get("desc", "")]
		btn.custom_minimum_size = Vector2(320, 0)
		var idx := i
		btn.pressed.connect(func(): upgrade_chosen.emit(idx))
		box.add_child(btn)
	upgrade_panel.visible = true
	_wire_all_buttons()

func hide_upgrade_ui() -> void:
	upgrade_panel.visible = false

func _make_center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	return label

func _make_progress_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 12)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	return bar

# ── Public UI state ────────────────────────────────
func show_menu_ui() -> void:
	hud_root.visible = false
	menu_panel.visible = true
	gunsmith_panel.visible = false
	result_panel.visible = false
	pause_panel.visible = false
	upgrade_panel.visible = false

func show_hud_ui() -> void:
	hud_root.visible = true
	menu_panel.visible = false
	gunsmith_panel.visible = false
	result_panel.visible = false
	pause_panel.visible = false
	upgrade_panel.visible = false

func show_gunsmith_ui() -> void:
	hud_root.visible = false
	menu_panel.visible = false
	gunsmith_panel.visible = true
	result_panel.visible = false
	pause_panel.visible = false
	upgrade_panel.visible = false

func show_pause_ui() -> void:
	hud_root.visible = true
	menu_panel.visible = false
	gunsmith_panel.visible = false
	result_panel.visible = false
	pause_panel.visible = true
	upgrade_panel.visible = false

func show_result_ui(title: String, stats: String) -> void:
	hud_root.visible = false
	menu_panel.visible = false
	gunsmith_panel.visible = false
	result_panel.visible = false
	pause_panel.visible = false
	upgrade_panel.visible = false
	result_panel.visible = true
	if result_title:
		result_title.text = title
	if result_stats:
		result_stats.text = stats

func set_menu_credits(credits: int, research: int) -> void:
	var label := menu_panel.find_child("CreditsLabel", true, false) as Label
	if label:
		label.text = "信用点 %d   研究数据 %d" % [credits, research]

func update_hud(player: PlayerController, valuable: int, extraction_progress: float = 0.0, inventory_summary: String = "", interaction_hint: String = "") -> void:
	health_label.text = "生命 %d / %d" % [int(player.health), int(player.max_health)]
	hunger_label.text = "饱食 %d / %d" % [int(player.hunger), int(player.max_hunger)]
	if health_bar:
		health_bar.value = player.health / maxf(player.max_health, 1.0) * 100.0
	if hunger_bar:
		hunger_bar.value = player.hunger / maxf(player.max_hunger, 1.0) * 100.0
	if player.weapon_controller:
		var w = player.weapon_controller.get_weapon()
		weapon_label.text = w.display_name if w else "空手"
		ammo_label.text = "弹药 %d / %d" % [player.weapon_controller.get_mag(), player.weapon_controller.get_reserve()]
	loot_label.text = "战利品价值 %d" % valuable
	if items_label:
		items_label.text = inventory_summary if not inventory_summary.is_empty() else "背包：空"
	if extraction_progress > 0.0:
		extraction_label.text = "撤离中…"
		extraction_bar.visible = true
		extraction_bar.value = extraction_progress * 100.0
	else:
		extraction_label.text = "前往绿色撤离点！"
		extraction_bar.visible = false
	if hint_label:
		hint_label.text = interaction_hint if not interaction_hint.is_empty() else "E 搜刮 | F 使用 | R 换弹 | 1/2 切枪"

func open_gunsmith(weapons: Array[WeaponData], attachments: Array[String], installed: Dictionary, content: ContentManager, upgrades: Array[UpgradeData] = [], levels: Dictionary = {}) -> void:
	_current_weapons = weapons
	_current_attachments = attachments
	_current_upgrades = upgrades
	_current_levels = levels
	_selected_weapon_id = weapons[0].id if weapons.size() > 0 else ""
	_refresh_gunsmith(content, installed)
	show_gunsmith_ui()

func _refresh_gunsmith(content: ContentManager, installed: Dictionary) -> void:
	# 清除旧按钮
	for child in weapons_box.get_children():
		child.queue_free()
	for child in attachments_box.get_children():
		child.queue_free()
	for child in upgrades_box.get_children():
		child.queue_free()

	# 武器选择
	for w in _current_weapons:
		var btn := Button.new()
		btn.text = w.display_name
		if w.id == _selected_weapon_id:
			btn.text += "  [已选]"
		btn.pressed.connect(func(): 
			_selected_weapon_id = w.id
			weapon_selected.emit(w.id)
			_refresh_gunsmith(content, installed)
		)
		weapons_box.add_child(btn)

	var status_text := "当前武器：%s" % _selected_weapon_id
	if _selected_weapon_id in installed:
		for slot in installed[_selected_weapon_id]:
			var att_id = installed[_selected_weapon_id][slot]
			var att: AttachmentData = content.get_attachment(att_id)
			if att:
				status_text += "\n%s: %s" % [slot, att.display_name]
	gunsmith_status.text = status_text

	if _current_attachments.is_empty():
		attachments_box.add_child(_make_label("暂无可用配件"))
	else:
		for att_id in _current_attachments:
			var att: AttachmentData = content.get_attachment(att_id)
			if att == null:
				continue
			var btn := Button.new()
			btn.text = "%s [%s]" % [att.display_name, att.slot]
			var pressed_id := att_id
			btn.pressed.connect(func(): attachment_selected.emit(pressed_id))
			attachments_box.add_child(btn)

	if _current_upgrades.is_empty():
		upgrades_box.add_child(_make_label("暂无强化项目"))
		_wire_all_buttons()
		return

	for up in _current_upgrades:
		var level := int(_current_levels.get(up.id, 0))
		var cost := int(up.cost_base * (level + 1))
		var btn := Button.new()
		if level >= up.max_level:
			btn.text = "%s  [已满级]" % up.display_name
			btn.disabled = true
		else:
			btn.text = "%s  Lv%d/%d  %d 信用点" % [up.display_name, level, up.max_level, cost]
		var up_id := up.id
		btn.pressed.connect(func(): upgrade_purchase_requested.emit(up_id))
		upgrades_box.add_child(btn)

	_wire_all_buttons()

func _load_ui_sfx() -> void:
	if ResourceLoader.exists(UI_CLICK_PATH):
		var res = load(UI_CLICK_PATH)
		if res is AudioStream:
			_ui_click_stream = res

func _play_ui_click() -> void:
	GameSfx.play(_ui_click_stream, randf_range(0.98, 1.02), 0.0, true)

func _wire_all_buttons() -> void:
	for child in root.find_children("*", "Button", true, false):
		var btn := child as Button
		if btn != null and not btn.pressed.is_connected(_play_ui_click):
			btn.pressed.connect(_play_ui_click)
