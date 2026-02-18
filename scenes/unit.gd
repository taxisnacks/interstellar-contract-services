class_name Unit
extends Node2D

signal unit_selected(unit)
signal unit_died(unit)

enum faction { PLAYER, ENEMY }

@export var max_hp := 10
@export var move_range := 6
@export var max_action_points := 2
@export var unit_faction: faction = faction.PLAYER
@export var tile_pos: Vector2i
@export var unit_sprite: Texture2D

var current_hp := max_hp
var action_points := max_action_points
var is_alive := true
var is_selected := false
var is_moving := false

func _ready():
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	$Sprite2D.texture = unit_sprite
	if unit_manager:
		unit_manager.register_unit(self)

	# Wait one frame for map to exist
	await get_tree().process_frame
	var map = get_tree().get_first_node_in_group("map")
	if map != null:
		tile_pos = map.world_to_tile(global_position)

func start_turn():
	action_points = max_action_points
	print(name, "start turn")

func end_turn():
	print(name, "end turn")

func set_selected(value: bool):
	is_selected = value
	queue_redraw()
	
func _draw():
	if is_selected:
		draw_circle(Vector2.ZERO, 20, Color(0.0, 0.609, 0.859, 0.302))
		
func _on_area_2d_input_event(viewport, event, shape_idx): # move to unitmanager later and flesh out
	if event is InputEventMouseButton and event.pressed:
		emit_signal("unit_selected", self)
		
func move_along_path(path: Array[Vector2i]) -> void:
	is_moving = true
	for i in range(1, path.size()):
		await move_to_tile_animated(path[i])
	is_moving = false

func move_to_tile_animated(tile: Vector2i) -> void:
	var map: Node2D = get_tree().get_first_node_in_group("map")
	tile_pos = tile
	var target: Vector2 = map.tile_to_world(tile)

	var tween := create_tween()
	tween.tween_property(self, "position", target, 0.15)
	await tween.finished

func spend_movement(cost: int) -> void:
	action_points -= cost
	action_points = max(action_points, 0)
	print("Movement taken, new AP:", action_points)

func execute_attack(attacker: Unit, target: Unit):
	# var hit_chance = (just for reference; need to research typical implementations of this)
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	print(attacker.name, " attacks ", target.name)
	
	attacker.action_points -= 1
	target.take_damage(3)
	unit_manager.deselect_active_unit()

func take_damage(amount: int):
	current_hp -= amount
	if current_hp <= 0:
		die()
		
func die():
	is_alive = false
	emit_signal ("unit_died", self)
	print("Unit died.")
	queue_free()
	
