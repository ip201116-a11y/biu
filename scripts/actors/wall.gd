@tool
extends StaticBody2D

# Default recovery time, overwritten by LDtk import
@export var recover_time: float = 1.0
@export var tile_size: int = 16 # Added tile_size to match other actors like Bomb

# Store initial layers to restore them later
var _initial_layer: int
var _initial_mask: int

func _ready() -> void:
	add_to_group("wall")
	
	# Layer 2: Blocks Player movement (Wall Layer)
	# Layer 4: Blocks Box Pushing (Box Layer)
	collision_layer = 2 + 4 
	collision_mask = 0 
	
	_initial_layer = collision_layer
	_initial_mask = collision_mask

# NEW: Handle LDtk field imports specifically for this object
func import_ldtk_fields(fields: Dictionary) -> void:
	if "recover_time" in fields:
		recover_time = fields.recover_time

# Interface called by Bomb.gd when exploded
# We ignore direction/force and simply destroy the wall
func apply_knockback(_direction: Vector2, _force: int) -> void:
	destroy()

func destroy() -> void:
	# Prevent multiple destruction calls
	if not visible: return

	print("Wall destroyed! Recovering in %s seconds." % recover_time)
	
	# Disable collision and hide visuals
	collision_layer = 0
	visible = false
	
	# Trigger chain reaction to adjacent walls
	_propagate_destruction()
	
	# Start recovery timer
	var timer = get_tree().create_timer(recover_time)
	timer.timeout.connect(_on_recover_timeout)

func _propagate_destruction() -> void:
	var space_state = get_world_2d().direct_space_state
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for dir in directions:
		# Check adjacent tiles
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position + (dir * tile_size)
		
		# Look specifically for Wall Layer (Bit 1 = Value 2)
		query.collision_mask = 2 
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		for result in results:
			var collider = result.collider
			
			# If we find a valid neighbor wall that hasn't been destroyed yet
			if is_instance_valid(collider) and collider != self:
				if collider.is_in_group("wall") and collider.has_method("destroy"):
					# This will call destroy(), which checks 'visible' to prevent infinite loops
					collider.destroy()

func _on_recover_timeout() -> void:
	# Recover the wall
	print("Wall recovering...")
	visible = true
	collision_layer = _initial_layer
