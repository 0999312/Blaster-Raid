class_name SurvivalController
extends Node

var player: PlayerController
var max_hunger := 100.0
var drain_per_second := 1.1
var starvation_damage_per_second := 1.5
var active := false

func setup(p_player: PlayerController, p_max_hunger: float, p_drain: float, p_starve: float) -> void:
	player = p_player
	max_hunger = p_max_hunger
	drain_per_second = p_drain
	starvation_damage_per_second = p_starve

func set_active(value: bool) -> void:
	active = value
	set_process(value)

func _process(delta: float) -> void:
	if not active or player == null:
		return
	if player.hunger <= 0.0:
		player.take_damage(starvation_damage_per_second * delta)
	else:
		player.spend_hunger(drain_per_second * delta)
