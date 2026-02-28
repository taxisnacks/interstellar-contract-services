extends Node

func choose_nearest_target(enemy: Unit, unit_manager):
	var nearest_target = null
	var current_nearest = 0
	if unit_manager.get_units_in_faction(Unit.faction.PLAYER) == null:
		return nearest_target
	for unit in unit_manager.get_units_in_faction(Unit.faction.PLAYER):
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
	print("Can't attack, no target found in range")
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
