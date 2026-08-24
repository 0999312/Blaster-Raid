class_name AimTrainerHUD
extends CanvasLayer

const FONT = preload("res://assets/fonts/MiSans-Semibold.ttf")

signal start_pressed
signal restart_pressed
signal resume_pressed

var score_label: Label
var timer_label: Label
var stats_label: Label
var menu_panel: PanelContainer
var pause_panel: PanelContainer
var end_panel: PanelContainer
var end_stats_label: Label
var crosshair: Control


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	crosshair = Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	var top_left := MarginContainer.new()
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.offset_left = 16.0
	top_left.offset_top = 12.0
	top_left.offset_right = 300.0
	top_left.offset_bottom = 52.0
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_left)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_font_override("font", FONT)
	score_label.text = "得分 0"
	top_left.add_child(score_label)

	var top_right := MarginContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -300.0
	top_right.offset_top = 12.0
	top_right.offset_right = -16.0
	top_right.offset_bottom = 52.0
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_right)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_font_override("font", FONT)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.text = "时间 0.0"
	top_right.add_child(timer_label)

	var bottom_left := MarginContainer.new()
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.offset_left = 16.0
	bottom_left.offset_top = -52.0
	bottom_left.offset_right = 520.0
	bottom_left.offset_bottom = -12.0
	bottom_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_left)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_font_override("font", FONT)
	stats_label.text = "命中 0 | 射击 0 | 准确率 0%"
	bottom_left.add_child(stats_label)

	menu_panel = _make_center_panel()
	root.add_child(menu_panel)
	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu_box)
	var title := Label.new()
	title.text = "3D FPS 练枪"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_font_override("font", FONT)
	menu_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "在 60 秒内尽量命中更多靶子\nWASD 移动 | 鼠标瞄准 | 左键射击 | Shift 疾跑 | 空格跳跃 | Esc 暂停"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", FONT)
	menu_box.add_child(subtitle)
	var start_btn := Button.new()
	start_btn.text = "开始训练"
	start_btn.custom_minimum_size = Vector2(220, 0)
	start_btn.add_theme_font_override("font", FONT)
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	menu_box.add_child(start_btn)

	pause_panel = _make_center_panel()
	pause_panel.visible = false
	root.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "已暂停"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 36)
	pause_title.add_theme_font_override("font", FONT)
	pause_box.add_child(pause_title)
	var resume_btn := Button.new()
	resume_btn.text = "继续训练"
	resume_btn.custom_minimum_size = Vector2(220, 0)
	resume_btn.add_theme_font_override("font", FONT)
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	pause_box.add_child(resume_btn)

	end_panel = _make_center_panel()
	end_panel.visible = false
	root.add_child(end_panel)
	var end_box := VBoxContainer.new()
	end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_box.add_theme_constant_override("separation", 12)
	end_panel.add_child(end_box)
	var end_title := Label.new()
	end_title.text = "训练结束"
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 36)
	end_title.add_theme_font_override("font", FONT)
	end_box.add_child(end_title)
	end_stats_label = Label.new()
	end_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_stats_label.add_theme_font_size_override("font_size", 24)
	end_stats_label.add_theme_font_override("font", FONT)
	end_box.add_child(end_stats_label)
	var restart_btn := Button.new()
	restart_btn.text = "再来一局"
	restart_btn.custom_minimum_size = Vector2(220, 0)
	restart_btn.add_theme_font_override("font", FONT)
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	end_box.add_child(restart_btn)


func _make_center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(460, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func set_score(value: int) -> void:
	score_label.text = "得分 %d" % value


func set_timer(value: float) -> void:
	timer_label.text = "时间 %.1f" % maxf(value, 0.0)


func set_stats(hits: int, shots: int, accuracy: float) -> void:
	stats_label.text = "命中 %d | 射击 %d | 准确率 %.0f%%" % [hits, shots, accuracy]


func show_menu(visible_flag: bool) -> void:
	menu_panel.visible = visible_flag
	_update_crosshair()


func show_pause(visible_flag: bool) -> void:
	pause_panel.visible = visible_flag
	_update_crosshair()


func show_end(visible_flag: bool, stats: Dictionary = {}) -> void:
	end_panel.visible = visible_flag
	if visible_flag:
		end_stats_label.text = "得分：%d\n命中：%d / %d\n准确率：%.1f%%\n每秒命中：%.2f" % [
			stats.get("score", 0),
			stats.get("hits", 0),
			stats.get("shots", 0),
			stats.get("accuracy", 0.0),
			stats.get("hps", 0.0),
		]
	_update_crosshair()


func _update_crosshair() -> void:
	crosshair.visible = not (menu_panel.visible or pause_panel.visible or end_panel.visible)


class Crosshair:
	extends Control

	func _draw() -> void:
		var center := get_viewport_rect().size / 2.0
		var gap := 5.0
		var length := 9.0
		var thickness := 2.0
		var color := Color(1, 1, 1, 0.9)
		draw_rect(Rect2(center.x - thickness * 0.5, center.y - gap - length, thickness, length), color)
		draw_rect(Rect2(center.x - thickness * 0.5, center.y + gap, thickness, length), color)
		draw_rect(Rect2(center.x - gap - length, center.y - thickness * 0.5, length, thickness), color)
		draw_rect(Rect2(center.x + gap, center.y - thickness * 0.5, length, thickness), color)
