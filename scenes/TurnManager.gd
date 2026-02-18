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
