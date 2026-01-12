extends StaticBody2D

# Matches the 'wall_layer' in your player script (Layer 2)
@export_flags_2d_physics var water_layer: int = 2 
@export var tile_map_layer: int = 1
@export var blast_range: int = 5

var _water_collider: Node = null
var _water_cell_pos: Vector2i
var _water_source_id: int = -1
var _water_atlas_coords: Vector2i = Vector2i(-1, -1)

var is_floating: bool = false
var tile_size: int = 16

func _ready() -> void:
	add_to_group("box")

func explode() -> void:
	print("Bomb exploded!")
	
	var space_state = get_world_2d().direct_space_state
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	# Detect and push targets
	for dir in directions:
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position + (dir * tile_size)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.collision_mask = 0xFFFFFFFF # Check everything
		
		var results = space_state.intersect_point(query)
		for result in results:
			var collider = result.collider
			if collider == self: continue
			
			# Constraint: If bomb is floating (in water), ONLY affect other floating boxes
			if is_floating:
				var collider_is_floating = false
				if collider.has_method("is_floating_object"):
					collider_is_floating = collider.is_floating_object()
				
				if not collider_is_floating:
					continue
			
			if collider.has_method("apply_knockback"):
				collider.apply_knockback(dir, blast_range)

	# Restore water if this bomb was a bridge
	if is_instance_valid(_water_collider):
		if ClassDB.class_exists("TileMapLayer") and _water_collider.is_class("TileMapLayer"):
			_water_collider.set_cell(_water_cell_pos, _water_source_id, _water_atlas_coords)
		elif _water_collider is TileMap:
			_water_collider.set_cell(0, _water_cell_pos, _water_source_id, _water_atlas_coords)

	queue_free()

# ------------------------------------------------------------------------------
# KNOCKBACK LOGIC (Shared with Box)
# ------------------------------------------------------------------------------
func apply_knockback(dir: Vector2, max_dist: int) -> void:
	var target_pos = global_position
	var space_state = get_world_2d().direct_space_state
	
	# Calculate furthest valid position (ignoring Water/Walls to fly over them)
	for i in range(1, max_dist + 1):
		var check_pos = global_position + (dir * tile_size * i)
		
		# Check for BLOCKING objects (Layer 4 = Box, Layer 32 = Floating/Bridge)
		# We ignore Layer 2 (Water/Wall) so we can fly over it.
		var query = PhysicsPointQueryParameters2D.new()
		query.position = check_pos
		query.collision_mask = 4 + 32 
		
		var results = space_state.intersect_point(query)
		if results.size() > 0:
			break # Blocked by another box/bomb
		
		target_pos = check_pos

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_pos, 0.4)
	tween.tween_callback(check_on_water)

# ------------------------------------------------------------------------------
# WATER / BRIDGE LOGIC
# ------------------------------------------------------------------------------
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
	print("Bomb splashed into water!")
	is_floating = true
	modulate = Color(0.7, 0.7, 0.8)
	
	# Stop being a pushable 'box' (Layer 4) and become a 'bridge' (Layer 6/Bit 32)
	# This allows players to walk on it, but Bombs can still detect it via mask 32.
	collision_layer = 32
	collision_mask = 0
	
	# Store water info
	if ClassDB.class_exists("TileMapLayer") and water_collider.is_class("TileMapLayer"):
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		_water_collider = water_collider
		_water_cell_pos = cell_pos
		_water_source_id = water_collider.get_cell_source_id(cell_pos)
		_water_atlas_coords = water_collider.get_cell_atlas_coords(cell_pos)
		water_collider.set_cell(cell_pos, -1)
	elif water_collider is TileMap:
		var local_pos = water_collider.to_local(global_position)
		var cell_pos = water_collider.local_to_map(local_pos)
		_water_collider = water_collider
		_water_cell_pos = cell_pos
		_water_source_id = water_collider.get_cell_source_id(0, cell_pos)
		_water_atlas_coords = water_collider.get_cell_atlas_coords(0, cell_pos)
		water_collider.set_cell(0, cell_pos, -1) 
	else:
		water_collider.queue_free()

func is_floating_object() -> bool:
	return is_floating
