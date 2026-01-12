extends Node2D

# SETTINGS
@export var tile_size: int = 16
@export var move_speed: float = 0.12 

# COLLISION MASKS
@export_flags_2d_physics var wall_layer: int = 2 
@export_flags_2d_physics var box_layer: int = 4

@onready var ray: RayCast2D = $RayCast2D
@onready var bomb_placer: Node2D = $BombPlacer 

var is_moving: bool = false
var input_buffer: Vector2 = Vector2.ZERO 

var inputs: Dictionary = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

func _unhandled_input(event: InputEvent) -> void:
	for dir in inputs.keys():
		if event.is_action_pressed(dir):
			attempt_move(inputs[dir])

func attempt_move(direction: Vector2) -> void:
	if bomb_placer:
		bomb_placer.update_direction(direction)
		
	if is_moving:
		input_buffer = direction
		return
	move(direction)

func move(direction: Vector2) -> void:
	var target_pos = position + (direction * tile_size)
	
	# 1. Check WALLS (Water)
	ray.target_position = direction * tile_size
	ray.collision_mask = wall_layer
	ray.force_raycast_update()
	
	if ray.is_colliding():
		return 

	# 2. Check BOXES
	ray.collision_mask = box_layer
	ray.force_raycast_update()
	
	if ray.is_colliding():
		var box = ray.get_collider()
		if box.is_in_group("box"):
			if can_push_box(box, direction):
				push_box(box, direction)
				move_player(target_pos)
		else:
			return 
	else:
		move_player(target_pos)

func can_push_box(box: Node2D, direction: Vector2) -> bool:
	var original_global_pos = ray.global_position
	ray.global_position = box.global_position
	ray.collision_mask = box_layer 
	ray.force_raycast_update()
	var is_blocked = ray.is_colliding()
	ray.global_position = original_global_pos
	return not is_blocked

func push_box(box: Node2D, direction: Vector2) -> void:
	var box_target = box.position + (direction * tile_size)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "position", box_target, move_speed)
	tween.tween_callback(Callable(box, "check_on_water"))

func move_player(target_pos: Vector2) -> void:
	is_moving = true
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, move_speed)
	tween.tween_callback(_on_move_finished)

func _on_move_finished() -> void:
	is_moving = false
	if input_buffer != Vector2.ZERO:
		var next_move = input_buffer
		input_buffer = Vector2.ZERO
		attempt_move(next_move)

# ------------------------------------------------------------------------------
# EXPLOSION KNOCKBACK
# ------------------------------------------------------------------------------
func apply_knockback(direction: Vector2, distance: int) -> void:
	if is_moving: return
	is_moving = true
	
	var start_pos = position
	# We assume explosion force sends player flying OVER walls/water
	var target_pos = position + (direction * tile_size * distance)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.4)
	
	tween.tween_callback(func():
		# Check if we landed on Safe Ground
		# We check for collisions with the 'Wall/Water' layer at our feet.
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position
		query.collision_mask = wall_layer # Layer 2
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		
		if results.size() > 0:
			# Landed on Water/Wall! Bounce back to safety.
			print("Player landed on water, returning...")
			var return_tween = create_tween()
			return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			return_tween.tween_property(self, "position", start_pos, 0.3)
			return_tween.tween_callback(func(): is_moving = false)
		else:
			is_moving = false
	)
