extends StaticBody2D

# Store initial physics layer to restore it when closing
var _initial_layer: int
var detectors: Array[Node] = []

func _ready() -> void:
	_initial_layer = collision_layer
	
	# 1. Find the Level Node
	# Hierarchy is typically: Level -> EntityLayer -> Door
	# So we go up two steps to find the Level root.
	var level_node = get_parent().get_parent()
	
	if not level_node:
		push_warning("Door '%s' could not find Level node (checked grandparent)." % name)
		return
	
	# 2. Find all Detectors in this Level
	# We search recursively in the Level node for any node of type DoorDetector
	detectors = level_node.find_children("*", "DoorDetector", true, false)
	
	# 3. Connect to their signals
	for detector in detectors:
		detector.state_changed.connect(_on_detector_state_changed)
	
	# 4. Initial Check (in case boxes start on buttons)
	_check_conditions()

func _on_detector_state_changed(_is_active: bool) -> void:
	_check_conditions()

func _check_conditions() -> void:
	# Requirement: ALL detectors in the level must be active
	if detectors.is_empty():
		return 

	var all_active = true
	for detector in detectors:
		if not detector.is_active:
			all_active = false
			break
	
	if all_active:
		open()
	else:
		close()

func open() -> void:
	if not visible: return # Already open
	
	# Disable collision and hide
	collision_layer = 0 
	visible = false 
	# Optional: Play sound here

func close() -> void:
	if visible: return # Already closed
	
	# Restore collision and show
	collision_layer = _initial_layer
	visible = true
