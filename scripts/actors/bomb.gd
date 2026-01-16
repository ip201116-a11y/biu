extends "res://scripts/actors/box.gd"

@export var blast_range: int = 5

func _ready() -> void:
	# Calls box.gd _ready() to setup groups ("box", "revertable") and layers
	super._ready()

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

	# Restore water if this bomb was a bridge before it dies
	if is_floating:
		restore_water()

	queue_free()
