extends Node2D

# SETTINGS
@export var tile_size: int = 16
@export var move_speed: float = 0.12 

# COLLISION MASKS
@export_flags_2d_physics var wall_layer: int = 2 
@export_flags_2d_physics var box_layer: int = 4

@onready var ray: RayCast2D = $RayCast2D
@onready var bomb_placer: Node2D = $BombPlacer 
@onready var history_manager: Node = $HistoryManager # Ensure you add this Child Node!
var is_moving: bool = false
var input_buffer: Vector2 = Vector2.ZERO 
var movement_tween: Tween # Track the active tween to allow cancelling

var inputs: Dictionary = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

func _ready() -> void:
	add_to_group("revertable")

func _unhandled_input(event: InputEvent) -> void:
	# UTILITY INPUTS
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_level()
		elif event.keycode == KEY_BACKSPACE:
			if history_manager:
				history_manager.undo_last_action()

	# MOVEMENT INPUTS
	for dir in inputs.keys():
		if event.is_action_pressed(dir):
			# Record state before moving
			if history_manager:
				history_manager.record_snapshot()
			attempt_move(inputs[dir])

# --- UPDATED LOGIC ---

func on_level_entered() -> void:
	# Called by Camera2D when entering a new room
	if history_manager:
		history_manager.save_checkpoint()

func reset_level() -> void:
	# Instead of reloading the scene, we restore the checkpoint
	if history_manager:
		history_manager.load_checkpoint()

# ---------------------

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
	
	if movement_tween: movement_tween.kill()
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "position", target_pos, move_speed)
	movement_tween.tween_callback(_on_move_finished)

func _on_move_finished() -> void:
	is_moving = false
	if input_buffer != Vector2.ZERO:
		var next_move = input_buffer
		input_buffer = Vector2.ZERO
		# Note: Snapshot handled in _unhandled_input for next move
		attempt_move(next_move)

# Triggered by BombPlacer input
func trigger_explosion_sequence() -> void:
	if is_moving: return
	bomb_placer.actual_explode_logic()

# ------------------------------------------------------------------------------
# KNOCKBACK LOGIC
# ------------------------------------------------------------------------------
func apply_knockback(direction: Vector2, distance: int) -> void:
	if is_moving: return
	is_moving = true
	
	var start_pos = position
	var target_pos = position + (direction * tile_size * distance)
	
	if movement_tween: movement_tween.kill()
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "position", target_pos, 0.4)
	
	movement_tween.tween_callback(func():
		# 1. Check if we landed on Water/Wall (Layer 2)
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position
		query.collision_mask = wall_layer 
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		
		# 2. Check if we landed in the Void (Outside Map)
		var is_in_void = false
		var camera = get_viewport().get_camera_2d()
		if camera and camera.has_method("is_point_in_level"):
			if not camera.is_point_in_level(global_position):
				is_in_void = true
		
		# Trigger respawn if on Water OR in Void
		if results.size() > 0 or is_in_void:
			print("Player landed on hazard (Water/Void), returning...")
			if movement_tween: movement_tween.kill()
			movement_tween = create_tween()
			movement_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			movement_tween.tween_property(self, "position", start_pos, 0.3)
			movement_tween.tween_callback(func(): is_moving = false)
		else:
			is_moving = false
	)

# ------------------------------------------------------------------------------
# BOX INTERACTION
# ------------------------------------------------------------------------------
func carried_by_box(target_pos: Vector2, duration: float) -> void:
	# Override any existing movement (including knockback)
	if movement_tween: movement_tween.kill()
	is_moving = true
	
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "global_position", target_pos, duration)
	
	# Assuming box handles safety (it's a bridge), so we just finish
	movement_tween.tween_callback(func(): is_moving = false)

func record_data() -> Dictionary:
	return {
		"position": position
	}

func restore_data(data: Dictionary) -> void:
	position = data.position
