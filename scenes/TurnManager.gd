extends Node

enum phase { PLAYER, ENEMY }

signal turn_started(phase)
signal turn_ended(phase)

var current_phase: int = phase.PLAYER
var player_units: Array = []

#Input function, should probably move
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_SPACE:
			var unit_manager = get_tree().get_first_node_in_group("unit_manager") 
			unit_manager.deselect_active_unit()
			end_player_turn()

func _ready():
	var unit_manager = get_tree().get_first_node_in_group("unit_manager") # grab units from UnitManager
	if unit_manager:
		player_units = unit_manager.get_units_in_faction(Unit.faction.PLAYER) # if not empty, get player units

func start_player_turn():
	var unit_manager = get_tree().get_first_node_in_group("unit_manager") # grab units from UnitManager
	if unit_manager:
		player_units = unit_manager.get_units_in_faction(Unit.faction.PLAYER) # if not empty, get player units
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

func enemy_turn():
	print (" ENEMY TURN START. ")
	current_phase = phase.ENEMY
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	if unit_manager == null:
		start_player_turn()
		return

	var enemies: Array[Unit] = unit_manager.get_units_in_faction(Unit.faction.ENEMY)
	for enemy in enemies:
		enemy.start_turn()
	for enemy in enemies:
		await take_enemy_action(enemy, unit_manager)
		await get_tree().create_timer(0.15).timeout
	print (" ENEMY TURN END. ")
	start_player_turn()

# ------ AI FUNCTIONS ------ # (move later, doesnt belong in turnmanager)
func choose_nearest_target(enemy: Unit, unit_manager):
	var player_units = unit_manager.get_units_in_faction(Unit.faction.PLAYER)
	if player_units.is_empty():
		print(enemy.name, " found no players to target.")
		return null
	var nearest_target: Unit = player_units[0]
	var current_nearest = enemy.tile_pos.distance_to(nearest_target.tile_pos)
	for unit in player_units:
		var current_distance = unit.tile_pos.distance_to(enemy.tile_pos)
		if current_distance < current_nearest:
			current_nearest = current_distance
			nearest_target = unit
	print(enemy.name, " targets ", nearest_target)
	return nearest_target 

func can_attack(enemy: Unit, target: Unit):
	return enemy.can_attack_target(target)

func take_enemy_action(enemy: Unit, unit_manager) -> void:
	if enemy == null or not enemy.is_alive:
		return
	if enemy.action_points <= 0:
		return

	var target: Unit = choose_nearest_target(enemy, unit_manager)
	if target == null or not target.is_alive:
		return

	# 1) Attack immediately if already in range
	if can_attack(enemy, target):
		enemy.execute_attack(target)
		return

	# 2) Otherwise move toward a tile that can attack, if possible
	var map = get_tree().get_first_node_in_group("map")
	if map == null:
		print(enemy.name, " tried to move, but failed to get node in map group")
		return

	var full_path: Array[Vector2i] = map.find_path(enemy.tile_pos, target.tile_pos, enemy)
	if full_path.is_empty():
		print(enemy.name, " tried to move but found path empty")
		return

	var chosen_tile: Vector2i = enemy.tile_pos
	var max_steps: int = min(enemy.move_range, full_path.size() - 1)

	# Prefer tiles that end in attack range after moving
	for i in range(1, max_steps + 1):
		var tile := full_path[i]
		var dist := tile.distance_to(target.tile_pos)
		if dist <= enemy.get_attack_range():
			chosen_tile = tile
			break
		chosen_tile = tile  # fallback: furthest progress this turn

	if chosen_tile != enemy.tile_pos:
		var move_path: Array[Vector2i] = map.find_path(enemy.tile_pos, chosen_tile, enemy)
		if not move_path.is_empty():
			print(enemy.name, " is moving.")
			await enemy.move_along_path(move_path)
			enemy.spend_movement(1) # or AP model of your choice

	# 3) Re-check attack after movement
	if enemy.action_points > 0 and can_attack(enemy, target):
		enemy.execute_attack(target)
