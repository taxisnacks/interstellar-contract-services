extends Node

enum phase { PLAYER, ENEMY }

signal turn_started(phase)
signal turn_ended(phase)

var current_phase: int = phase.PLAYER
var player_units: Array = []

func _ready():
	var unit_manager = get_tree().get_first_node_in_group("unit_manager") # grab player units from UnitManager
	if unit_manager:
		player_units = unit_manager.units

func start_player_turn():
	current_phase = phase.PLAYER
	print(" PLAYER TURN START. ")
	
	for unit in player_units:
		unit.start_turn()
		
	emit_signal("turn_started", current_phase)

func end_player_turn():
	print (" PLAYER TURN END. ")
	
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	if unit_manager:
		unit_manager.active_unit = null
	
	emit_signal("turn_ended", current_phase)
	enemy_turn()
	
func choose_nearest_target(enemy: Unit):
	var nearest_target = null
	var current_furthest = 0
	if player_units.is_empty():
		return nearest_target
	for unit in player_units:
		var current_distance = unit.distance_to(enemy.tile_pos)
		if current_distance > current_furthest:
			current_furthest = current_distance
			nearest_target = unit
	return nearest_target 
	
func can_attack(enemy: Unit, target: Unit):
	if enemy.distance_to(target.tile_pos) < enemy.get_attack_range():
		return true
	return false
func take_enemy_action(enemy: Unit, map, unit_manager):
	# for each unit in enemy_units:
		var target = choose_nearest_target(enemy)
		if can_attack(enemy, target):
			enemy.execute_attack(target)
	  # else:
		   #move towards target via map	as far as possible
		   #recheck can_attack
				#else move on to next unit
				
func enemy_turn(): # placeholder
	current_phase = phase.ENEMY
	print(" ENEMY TURN START. ")
	
	# enemy AI probably needs to go here later, for now just wait a second for debug
	await get_tree().create_timer(1.0).timeout
	
	print(" ENEMY TURN END. ")
	start_player_turn()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_SPACE:
			end_player_turn()
