extends Node

enum phase { PLAYER, ENEMY }

signal turn_started(phase)
signal turn_ended(phase)

var current_phase: int = phase.PLAYER
var player_units: Array = []

func _ready():
	var unit_manager = get_tree().get_first_node_in_group("unit_manager") # grab player units from UnitManager
	if unit_manager:
		player_units = unit_manager.get_units_in_faction(Unit.faction.PLAYER)

func start_player_turn():
	var unit_manager = get_tree().get_first_node_in_group("unit_manager") # grab player units from UnitManager
	if unit_manager:
		player_units = unit_manager.get_units_in_faction(Unit.faction.PLAYER)
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

func choose_nearest_target(enemy: Unit, unit_manager):
	var nearest_target = null
	var player_units = unit_manager.get_units_in_faction(Unit.faction.PLAYER)
	if player_units == null:
		return nearest_target
	var current_nearest = player_units[1].tile_pos.distance_to(enemy.tile_pos)
	for unit in player_units:
		var current_distance = unit.tile_pos.distance_to(enemy.tile_pos)
		if current_distance < current_nearest:
			current_nearest = current_distance
			nearest_target = unit
	return nearest_target 

func can_attack(enemy: Unit, target: Unit):
	if target == null:
		return false
	if enemy.tile_pos.distance_to(target.tile_pos) < enemy.get_attack_range():
		print(enemy, "in range of ", target, ", can attack")
		return true
	print ("Can't attack, no targets found in range")
	return false

func take_enemy_action(enemy: Unit, unit_manager):
	# for each unit in enemy_units:
		var target = choose_nearest_target(enemy, unit_manager)
		if can_attack(enemy, target):
			enemy.execute_attack(target)
	  # else:
		   #move towards target via map	as far as possible
		   #recheck can_attack
				#else move on to next unit

func enemy_turn(): # placeholder
	current_phase = phase.ENEMY
	print(" ENEMY TURN START. ")
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	for unit in unit_manager.get_units_in_faction(Unit.faction.ENEMY):
		take_enemy_action(unit, unit_manager)
	# enemy AI probably needs to go here later, for now just wait a second for debug
	await get_tree().create_timer(1.0).timeout
	
	print(" ENEMY TURN END. ")
	start_player_turn()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_SPACE:
			end_player_turn()
