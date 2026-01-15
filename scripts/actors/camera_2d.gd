extends Camera2D

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
@export_group("Targets")
@export var player: Node2D
@export var levels_parent: Node2D

@export_group("Settings")
@export var follow_speed: float = 15.0
@export var transition_duration: float = 0.6
@export var transition_type: Tween.TransitionType = Tween.TRANS_BACK
@export var transition_ease: Tween.EaseType = Tween.EASE_OUT
@export var debug_draw: bool = true # Enable this to see the level bounds!

# ------------------------------------------------------------------------------
# Internal State
# ------------------------------------------------------------------------------
var current_level: Node2D = null
var is_transitioning: bool = false
var view_size: Vector2

func _ready() -> void:
	position_smoothing_enabled = false
	
	# Try to find start room immediately
	if player and levels_parent:
		current_level = _find_level_containing(player.global_position)
		if current_level:
			print("Start level found: ", current_level.name)
			_snap_to_target()
			
			# TRIGGER INITIAL CHECKPOINT
			if player.has_method("on_level_entered"):
				player.on_level_entered()
		else:
			print("Warning: Player started in the void (no level found).")

func _process(delta: float) -> void:
	if not player: return
	
	_update_view_size()
	
	# 1. Room Detection Logic
	# If we have no room, or the player has left the current room rect...
	if current_level == null or not _is_point_inside_level(player.global_position, current_level):
		var new_level = _find_level_containing(player.global_position)
		
		if new_level and new_level != current_level:
			print("Switching room to: ", new_level.name)
			_change_room(new_level)
	
	# 2. Movement Logic
	if is_transitioning:
		pass # Tween handles this
	elif current_level:
		# ROOM MODE: Smoothly follow player within bounds
		var target_pos = player.global_position
		var clamped_pos = _get_clamped_position(target_pos, current_level)
		global_position = global_position.lerp(clamped_pos, follow_speed * delta)
	else:
		# VOID MODE: Just follow the player if no level is defined
		global_position = player.global_position

	# 3. Debug Draw Update
	if debug_draw:
		queue_redraw()

# ------------------------------------------------------------------------------
# Room Logic
# ------------------------------------------------------------------------------

func _change_room(new_level: Node2D) -> void:
	current_level = new_level
	is_transitioning = true
	
	# TRIGGER CHECKPOINT
	if player.has_method("on_level_entered"):
		player.on_level_entered()
	
	var target_pos = _get_clamped_position(player.global_position, new_level)
	
	var tween = create_tween()
	tween.set_trans(transition_type).set_ease(transition_ease)
	tween.tween_property(self, "global_position", target_pos, transition_duration)
	tween.tween_callback(func(): is_transitioning = false)

func _snap_to_target():
	if current_level:
		global_position = _get_clamped_position(player.global_position, current_level)

func _get_clamped_position(target: Vector2, level: Node2D) -> Vector2:
	# IMPORTANT: Convert Vector2i (from LDTK) to Vector2
	var lvl_size = Vector2(level.size) 
	var lvl_pos = level.global_position
	
	var half_view = (view_size / zoom) * 0.5
	var x = target.x
	var y = target.y
	
	# Clamp X
	if lvl_size.x > (half_view.x * 2):
		x = clamp(x, lvl_pos.x + half_view.x, lvl_pos.x + lvl_size.x - half_view.x)
	else:
		x = lvl_pos.x + (lvl_size.x / 2.0)
		
	# Clamp Y
	if lvl_size.y > (half_view.y * 2):
		y = clamp(y, lvl_pos.y + half_view.y, lvl_pos.y + lvl_size.y - half_view.y)
	else:
		y = lvl_pos.y + (lvl_size.y / 2.0)
		
	return Vector2(x, y)

# ------------------------------------------------------------------------------
# Search Helpers
# ------------------------------------------------------------------------------

func _find_level_containing(pos: Vector2) -> Node2D:
	if not levels_parent: return null
	
	# Brute force search (Safest method)
	for child in levels_parent.get_children():
		if _is_point_inside_level(pos, child):
			return child
	return null

func _is_point_inside_level(pos: Vector2, level: Node2D) -> bool:
	if "size" not in level: 
		return false
	
	# Construct the Rect based on Global Position and Size
	var lvl_size = Vector2(level.size)
	var rect = Rect2(level.global_position, lvl_size)
	
	return rect.has_point(pos)

func is_point_in_level(pos: Vector2) -> bool:
	return _find_level_containing(pos) != null

func _update_view_size():
	view_size = get_viewport_rect().size

# ------------------------------------------------------------------------------
# Debugging (Draws boxes on screen)
# ------------------------------------------------------------------------------
func _draw():
	if not debug_draw or not levels_parent: return
	
	# Draw Current Level (RED)
	if current_level:
		var rect = Rect2(current_level.global_position, Vector2(current_level.size))
		draw_rect(transform.affine_inverse() * rect, Color(1, 0, 0, 0.3), false, 4.0)

	# Draw Mouse/Player Over Level (YELLOW)
	if player:
		var found = _find_level_containing(player.global_position)
		if found and found != current_level:
			var rect = Rect2(found.global_position, Vector2(found.size))
			draw_rect(transform.affine_inverse() * rect, Color(1, 1, 0, 0.3), false, 4.0)
