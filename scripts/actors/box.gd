extends AnimatableBody2D

@export_flags_2d_physics var water_layer: int = 2 
@export var tile_map_layer: int = 1

var is_floating: bool = false
var tile_size: int = 16

# Water Restoration Data
var _water_collider: Node = null
var _water_cell_pos: Vector2i
var _water_source_id: int = -1
var _water_atlas_coords: Vector2i = Vector2i(-1, -1)

# Initial Physics Layers
var _initial_layer: int
var _initial_mask: int

func _ready() -> void:
	add_to_group("box")
	add_to_group("revertable")
	_initial_layer = collision_layer
	_initial_mask = collision_mask

func check_on_water() -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = water_layer
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	if results.size() > 0:
		become_bridge(results[0].collider)

func become_bridge(water_collider: Node) -> void:
	print("Box splashed into water!")
	is_floating = true
	
	modulate = Color(0.7, 0.7, 0.8) 
	remove_from_group("box")
	
	# Move to Layer 6 (Bit 32) so Player walks over it, but Bomb detects it
	collision_layer = 32
	collision_mask = 0
	
	_water_collider = water_collider
	
	if ClassDB.class_exists("TileMapLayer") and water_collider.is_class("TileMapLayer"):
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		
		# Store Cell Data
		_water_cell_pos = cell_pos
		_water_source_id = water_collider.get_cell_source_id(cell_pos)
		_water_atlas_coords = water_collider.get_cell_atlas_coords(cell_pos)
		
		water_collider.set_cell(cell_pos, -1)
	elif water_collider is TileMap:
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		
		# Store Cell Data
		_water_cell_pos = cell_pos
		_water_source_id = water_collider.get_cell_source_id(0, cell_pos)
		_water_atlas_coords = water_collider.get_cell_atlas_coords(0, cell_pos)
		
		water_collider.set_cell(0, cell_pos, -1) 
	else:
		water_collider.queue_free()

func restore_water() -> void:
	if is_instance_valid(_water_collider):
		if ClassDB.class_exists("TileMapLayer") and _water_collider.is_class("TileMapLayer"):
			_water_collider.set_cell(_water_cell_pos, _water_source_id, _water_atlas_coords)
		elif _water_collider is TileMap:
			_water_collider.set_cell(0, _water_cell_pos, _water_source_id, _water_atlas_coords)
	
	is_floating = false
	_water_collider = null
	
	modulate = Color.WHITE
	add_to_group("box")
	collision_layer = _initial_layer
	collision_mask = _initial_mask

func is_floating_object() -> bool:
	return is_floating

# Physics Push Logic
func apply_knockback(dir: Vector2, max_dist: int) -> void:
	var target_pos = global_position
	var space_state = get_world_2d().direct_space_state
	
	# Fly over water/walls, stop only at other boxes
	for i in range(1, max_dist + 1):
		var check_pos = global_position + (dir * tile_size * i)
		
		var query = PhysicsPointQueryParameters2D.new()
		query.position = check_pos
		
		# UPDATED: Include Layer 1 (Player) so the box stops at the player
		# Mask 1 (Player) + 4 (Boxes) + 32 (Existing Bridges)
		query.collision_mask = 1 + 4 + 32 
		
		var results = space_state.intersect_point(query)
		if results.size() > 0:
			break 
		
		target_pos = check_pos

	# If we are actually moving and were floating, restore the water behind us
	if target_pos != global_position and is_floating:
		restore_water()

	# Check if Player is on top of us and move them too
	var p_query = PhysicsPointQueryParameters2D.new()
	p_query.position = global_position
	p_query.collision_mask = 0xFFFFFFFF # Check everything
	p_query.collide_with_bodies = true
	
	var p_results = space_state.intersect_point(p_query)
	for result in p_results:
		var col = result.collider
		# If the collider is the player (checks via method presence), move them
		if col.has_method("carried_by_box"):
			col.carried_by_box(target_pos, 0.4)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_pos, 0.4)
	tween.tween_callback(check_on_water)
func get_snapshot() -> Dictionary:
	return {
		"node": self,
		"pos": global_position,
		"is_floating": is_floating,
		"water_data": {
			"collider": _water_collider,
			"cell_pos": _water_cell_pos,
			"source_id": _water_source_id,
			"atlas_coords": _water_atlas_coords
		}
	}

func restore_snapshot(data: Dictionary) -> void:
	global_position = data.pos
	
	# Handle State Transition: Floating <-> Solid
	if data.is_floating and not is_floating:
		# Force into floating state (without needing collision check)
		become_bridge_from_data(data.water_data)
	elif not data.is_floating and is_floating:
		restore_water()

func become_bridge_from_data(w_data: Dictionary) -> void:
	# Manually set state to floating using saved data
	is_floating = true
	modulate = Color(0.7, 0.7, 0.8)
	remove_from_group("box")
	collision_layer = 32
	collision_mask = 0
	
	_water_collider = w_data.collider
	_water_cell_pos = w_data.cell_pos
	_water_source_id = w_data.source_id
	_water_atlas_coords = w_data.atlas_coords
	
	# Ensure the tile is actually removed (visually)
	if is_instance_valid(_water_collider):
		if _water_collider is TileMapLayer or _water_collider is TileMap:
			# Note: Simplify based on your version, assuming standard set_cell methods
			if _water_collider.has_method("set_cell"):
				# Handle TileMap vs TileMapLayer signature differences
				if _water_collider is TileMap:
					_water_collider.set_cell(0, _water_cell_pos, -1)
				else:
					_water_collider.set_cell(_water_cell_pos, -1)
func record_data() -> Dictionary:
	return get_snapshot()

func restore_data(data: Dictionary) -> void:
	restore_snapshot(data)
	
	# Stop any active movement tweens immediately
	var t = create_tween()
	t.kill()
