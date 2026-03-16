class_name Unit
extends Node2D

signal unit_selected(unit)
signal unit_died(unit)

enum faction { PLAYER, ENEMY }

@export var unit_data: UnitResource
@export var unit_faction: faction = faction.PLAYER
@export var tile_pos: Vector2i
@export var unit_sprite: Texture2D
@export var weapon: WeaponResource
@export var unarmed_range := 1
@export var unarmed_damage := 1

var current_hp := unit_data.max_hp
var action_points := unit_data.max_action_points
var is_alive := true
var is_selected := false
var is_moving := false

func _ready():
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")

	current_hp = unit_data.max_hp
	action_points = unit_data.max_action_points
	$Sprite2D.texture = unit_sprite
	if unit_manager:
		unit_manager.register_unit(self)

	# Wait one frame for map to exist
	await get_tree().process_frame
	var map = get_tree().get_first_node_in_group("map")
	if map != null:
		tile_pos = map.world_to_tile(global_position)

func start_turn():
	action_points = unit_data.max_action_points
	print(name, " starts turn")

func end_turn():
	print(name, " ends turn")

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

func execute_attack(target: Unit):
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	
	print(self.name, " attacks ", target.name)
	self.action_points -= 1
	if roll_hit(target):
		target.take_damage(roll_damage())
	else:
		print(self.name, "'s attack missed")
	
	if unit_manager and unit_manager.active_unit == self:
		unit_manager.deselect_active_unit()

func can_attack_target(target: Unit) -> bool:
	if target == null or not target.is_alive:
		return false

	if tile_pos.distance_to(target.tile_pos) > get_attack_range():
		return false

	var map = get_tree().get_first_node_in_group("map")
	if map == null:
		return false

	return map.has_line_of_sight(tile_pos, target.tile_pos)

func get_attack_range():
	if weapon == null:
		return unarmed_range
	return weapon.range

func roll_damage():
	if weapon == null:
		return unarmed_damage
	return randi_range(weapon.damage_min, weapon.damage_max)

func get_hit_chance(target: Unit) -> int:
	if target == null:
		return 0

	var weapon_accuracy_bonus := 0
	if weapon != null:
		weapon_accuracy_bonus = weapon.accuracy_bonus

	var map = get_tree().get_first_node_in_group("map")
	var cover_penalty := 0
	if map != null:
		cover_penalty = map.get_tile_cover(target.tile_pos) * 15

	var hit_chance = unit_data.aim + weapon_accuracy_bonus - target.unit_data.defense - cover_penalty - get_range_penalty(target)
	if hit_chance < 1:
		hit_chance = 1
	if hit_chance > 99:
		hit_chance = 99
	return hit_chance

func get_range_penalty(target: Unit) -> int:
	var distance: int = int(tile_pos.distance_to(target.tile_pos))
	return max(0, (distance - 1) * 5)

func roll_hit(target: Unit) -> bool:
	var hit_roll: int = randi_range(1, 100)
	var chance: int = get_hit_chance(target)
	print("Hit roll ", hit_roll, " vs chance ", chance)
	return hit_roll <= chance

func take_damage(amount: int):
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	is_alive = false
	emit_signal ("unit_died", self)
	print("Unit died.")
	queue_free()
