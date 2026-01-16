extends Area2D
class_name DoorDetector

signal state_changed(is_active: bool)

var is_active: bool = false

func _ready() -> void:
	# Enable monitoring
	monitoring = true
	monitorable = false
	
	# Visual feedback (Start inactive)
	modulate = Color(0.5, 1.5, 0.5)

func _physics_process(_delta: float) -> void:
	var bodies = get_overlapping_bodies()
	var found_valid_body = false
	
	for body in bodies:
		if body.is_in_group("box"):
			if global_position.distance_to(body.global_position) <= 8.0:
				found_valid_body = true
				break
	
	_update_state(found_valid_body)

func _update_state(new_state: bool) -> void:
	if is_active != new_state:
		is_active = new_state
		state_changed.emit(is_active)
		
		# Visual Feedback
		if is_active:
			modulate = Color(0.5, 1.5, 0.5) # Glow Green
		else:
			modulate = Color(0.5, 1.5, 0.5)
