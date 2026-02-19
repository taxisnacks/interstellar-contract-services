extends Node2D
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var unit_manager = get_tree().get_first_node_in_group("unit_manager")

var debug_start_tile: Vector2i = Vector2i(-1, -1)
var debug_end_tile: Vector2i = Vector2i(-1, -1)
var debug_path: Array[Vector2i] = []

var hover_tile: Vector2i = Vector2i(-1, -1)
var hover_target = null
var preview_path: Array[Vector2i] = []

var attack_target: Unit = null

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(world_pos))

func tile_to_world(tile: Vector2i) -> Vector2:
	return tilemap.map_to_local(tile)


# DEBUG
# change for this: if unit_selected = true
# func _input(event):
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#var world_pos = get_global_mouse_position()
		#var tile = world_to_tile(world_pos)
#
		## first click = start
		#if debug_start_tile == Vector2i(-1, -1):
			#debug_start_tile = tile
			#print("Start tile set:", tile)
			#debug_path.clear()
#
		## second click = end + pathfind
		#else:
			#debug_end_tile = tile
			#debug_path = find_path(debug_start_tile, debug_end_tile, unit_manager.active_unit)
			#print("End tile set:", tile)
			#print("Path:", debug_path)
#
			## reset for next test
			#debug_start_tile = Vector2i(-1, -1)
#
		#queue_redraw()

func is_tile_walkable(tile_pos: Vector2i) -> bool:
	var tile_data = tilemap.get_cell_tile_data(tile_pos)
	if tile_data == null:
		return false
	return tile_data.get_custom_data("walkable") == true

var astar := AStarGrid2D.new()

func _ready():
	print("TileMap pos:", tilemap.position)
	print("Map pos:", position)

	if unit_manager:
		unit_manager.active_unit_changed.connect(_on_active_unit_changed)
	astar.cell_size = tilemap.tile_set.tile_size # for visualization later
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER

	var used_rect = tilemap.get_used_rect()
	astar.region = used_rect
	astar.update()

	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var pos = Vector2i(x, y)
			astar.set_point_solid(pos, not is_tile_walkable(pos))

func find_path(from_tile: Vector2i, to_tile: Vector2i, mover: Unit) -> Array[Vector2i]:
	apply_unit_obstacles(mover)

	var path: Array[Vector2i] = []
	if not astar.is_point_solid(to_tile):
		path = astar.get_id_path(from_tile, to_tile)

	clear_unit_obstacles()
	return path


func get_reachable_tiles(from_tile: Vector2i, max_cost: int, mover: Unit) -> Array[Vector2i]:
	apply_unit_obstacles(mover)

	var reachable: Array[Vector2i] = []

	for x in range(astar.region.position.x, astar.region.position.x + astar.region.size.x):
		for y in range(astar.region.position.y, astar.region.position.y + astar.region.size.y):
			var tile := Vector2i(x, y)

			if astar.is_point_solid(tile):
				continue

			var path := astar.get_id_path(from_tile, tile)
			if path.is_empty():
				continue

			var cost := path.size() - 1
			if cost <= max_cost:
				reachable.append(tile)

	clear_unit_obstacles()
	return reachable

var reachable_tiles: Array[Vector2i] = []

func _draw():
	
	# REACHABLE PREVIEW
	for tile in reachable_tiles:
		var center := tile_to_world(tile)
		draw_rect(
			Rect2(center - Vector2(8, 8), Vector2(16, 16)),
			Color(0.086, 0.322, 1.0, 0.396)
		)

	# PATH PREVIEW
	for tile in preview_path:
		var center := tile_to_world(tile)
		draw_circle(center, 6, Color(1, 1, 0, 0.8))
	
	# ATTACK PREVIEW
	if attack_target:
		draw_circle(
			attack_target.global_position,
			18,
			Color(1.0, 0.2, 0.2, 0.85)
		)


func _on_active_unit_changed(unit):
	if unit == null:
		# Clear all selection-related visuals
		clear_action_state()
	pass

func _process(_delta):
	var unit = unit_manager.active_unit
	if unit_manager == null or unit == null:
		return
	if unit.is_moving:
		return
	
	var tile := world_to_tile(get_global_mouse_position())
	if tile == hover_tile:
		return

	hover_tile = tile
	hover_target = unit_manager.get_unit_at_tile(tile)
	attack_target = null
	preview_path.clear()

	# ATTACK PREVIEW
	if hover_target != null \
	and hover_target.unit_faction != unit.unit_faction \
	and is_target_in_attack_range(unit, hover_target):
		print("Target found successfully")
		attack_target = hover_target
		
	# MOVEMENT PREVIEW
	elif tile in reachable_tiles:
		var unit_tile = world_to_tile(unit.global_position)
		preview_path = find_path(unit_tile, tile, unit)
	
	# DEBUG print("Hover: ", hover_target, "Attack target: ", attack_target) 
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		
		var unit = unit_manager.active_unit
		if unit == null or unit.action_points <= 0:
			return

		# ATTACK
		if attack_target:
			unit.execute_attack(attack_target)
			clear_action_state()
			return

		# MOVE
		if preview_path.is_empty():
			return

		if unit == null:
			return

		if unit.action_points <= 0:
			print("Insufficient AP, cannot move!")
			return

		# await movement
		await unit.move_along_path(preview_path)

		# spend movement AFTER animation
		unit.spend_movement(1)
		
		# deselect unit (optional, unsure yet if want(i.e action after move))
		unit.set_selected(false)
		unit_manager.active_unit = null

		# Clear visuals
		clear_action_state()

func apply_unit_obstacles(except_unit: Unit = null):
	for unit in unit_manager.units:
		if not unit.is_alive:
			continue
		if unit == except_unit:
			continue

		astar.set_point_solid(unit.tile_pos, true)

func clear_unit_obstacles():
	for unit in unit_manager.units:
		astar.set_point_solid(unit.tile_pos, false)

func clear_action_state():
	preview_path.clear()
	reachable_tiles.clear()
	attack_target = null
	queue_redraw()

func is_target_in_attack_range(attacker: Unit, target: Unit) -> bool:
	return attacker.tile_pos.distance_to(target.tile_pos) <= 5
