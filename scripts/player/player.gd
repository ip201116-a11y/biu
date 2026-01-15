extends Node2D

# SETTINGS
@export var tile_size: int = 16
@export var move_speed: float = 0.12 

# COLLISION MASKS
@export_flags_2d_physics var wall_layer: int = 2 
@export_flags_2d_physics var box_layer: int = 4

@onready var ray: RayCast2D = $RayCast2D
@onready var bomb_placer: Node2D = $BombPlacer 
@onready var history_manager: Node = $HistoryManager

var is_moving: bool = false
var input_buffer: Vector2 = Vector2.ZERO 
var movement_tween: Tween 
var _target_pos: Vector2

# NEW: Flags to track knockback state and deferred checkpoints
var is_knockback_active: bool = false
var has_pending_level_entry: bool = false

var inputs: Dictionary = {
	"ui_right": Vector2.RIGHT,
	"ui_left": Vector2.LEFT,
	"ui_up": Vector2.UP,
	"ui_down": Vector2.DOWN
}

func _ready() -> void:
	add_to_group("revertable")
	_target_pos = position 

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
			if history_manager:
				history_manager.record_snapshot()
			attempt_move(inputs[dir])

# --- UPDATED CHECKPOINT LOGIC ---

func on_level_entered() -> void:
	# Called by Camera2D when entering a new room.
	
	# CRITICAL FIX: If we are uncontrolled (knockback), DO NOT save yet.
	# We might be flying over a void or hazard.
	if is_knockback_active:
		has_pending_level_entry = true
		return

	# Normal movement (safe): Save checkpoint immediately.
	if history_manager:
		history_manager.save_checkpoint()

func reset_level() -> void:
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
	
	# 1. Check WALLS
	ray.target_position = direction * tile_size
	ray.collision_mask = wall_layer
	ray.force_raycast_update()
	if ray.is_colliding(): return 

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
	_target_pos = target_pos 
	
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
		attempt_move(next_move)

func trigger_explosion_sequence() -> void:
	if is_moving: return
	bomb_placer.actual_explode_logic()

# ------------------------------------------------------------------------------
# KNOCKBACK LOGIC (Updated to Prevent Bad Checkpoints)
# ------------------------------------------------------------------------------
func apply_knockback(direction: Vector2, distance: int) -> void:
	if is_moving: return
	is_moving = true
	
	# Enable Knockback Protection Flags
	is_knockback_active = true
	has_pending_level_entry = false
	
	var target_pos = position + (direction * tile_size * distance)
	_target_pos = target_pos 
	
	if movement_tween: movement_tween.kill()
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "position", target_pos, 0.4)
	
	movement_tween.tween_callback(func():
		# 1. Check Hazard (Water/Wall)
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position
		query.collision_mask = wall_layer 
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var results = space_state.intersect_point(query)
		
		# 2. Check Void
		var is_in_void = false
		var camera = get_viewport().get_camera_2d()
		if camera and camera.has_method("is_point_in_level"):
			if not camera.is_point_in_level(global_position):
				is_in_void = true
		
		# --- HAZARD LOGIC ---
		if results.size() > 0 or is_in_void:
			print("Player landed on hazard. Resetting to LAST SAFE checkpoint...")
			
			if movement_tween: movement_tween.kill()
			
			# Reset flags BEFORE loading (so we don't block the restore)
			is_moving = false
			is_knockback_active = false
			has_pending_level_entry = false # Discard the pending tag (it was bad)
			
			if history_manager:
				history_manager.load_checkpoint()
				
		# --- SAFE LANDING ---
		else:
			is_moving = false
			is_knockback_active = false
			
			# If we entered a new room mid-air, we skipped saving.
			# Now that we are safe, we commit that checkpoint.
			if has_pending_level_entry:
				has_pending_level_entry = false
				print("Knockback finished safely. Saving deferred checkpoint.")
				if history_manager:
					history_manager.save_checkpoint()
	)

# ------------------------------------------------------------------------------
# BOX INTERACTION
# ------------------------------------------------------------------------------
func carried_by_box(target_pos: Vector2, duration: float) -> void:
	if movement_tween: movement_tween.kill()
	is_moving = true
	_target_pos = target_pos 
	
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "global_position", target_pos, duration)
	movement_tween.tween_callback(func(): is_moving = false)

func record_data() -> Dictionary:
	return {
		"position": _target_pos if is_moving else position
	}

func restore_data(data: Dictionary) -> void:
	# Clean up any active movement or flags when restoring
	if movement_tween: movement_tween.kill()
	is_moving = false
	is_knockback_active = false
	has_pending_level_entry = false
	
	position = data.position
	_target_pos = data.position
