extends Node

# Configuration
@export var max_history: int = 50

# State
var state_history: Array[Dictionary] = []

func record_snapshot() -> void:
	var snapshot = _capture_state()
	state_history.append(snapshot)
	if state_history.size() > max_history:
		state_history.pop_front()

func undo_last_action() -> void:
	if state_history.is_empty():
		return
	
	# Optional: Prevent undo during movement if the parent Player is moving
	var player = get_parent()
	if player and player.get("is_moving"):
		return

	var snapshot = state_history.pop_back()
	restore_state(snapshot)

# --- NEW CHECKPOINT LOGIC (TAG SYSTEM) ---

func save_checkpoint() -> void:
	# Tags the latest history snapshot as a "Restart Point"
	# FIX: Record a new snapshot to capture the state *after* entering the level
	record_snapshot()
	
	if not state_history.is_empty():
		state_history.back()["is_tag"] = true
		print("Checkpoint tagged at history step: %d" % state_history.size())

func load_checkpoint() -> void:
	if state_history.is_empty():
		return
	
	print("Loading checkpoint (Rewinding to tag)...")
	
	# Undo until we find a tag or run out of history
	while not state_history.is_empty():
		var current_snapshot = state_history.back()
		
		# If we found the tag, restore it and stop (keeping it in history)
		if current_snapshot.get("is_tag", false):
			restore_state(current_snapshot)
			break
		
		# Otherwise, standard undo (pops and restores)
		undo_last_action()

# --- HELPERS ---

func _capture_state() -> Dictionary:
	var snapshot = {}
	# Find all nodes that implement the 'revertable' interface
	var revertables = get_tree().get_nodes_in_group("revertable")
	
	for node in revertables:
		# We use the node's path as the unique ID for persistent objects
		var path = node.get_path()
		
		# Call the interface method
		if node.has_method("record_data"):
			snapshot[path] = node.record_data()
	return snapshot

func restore_state(snapshot: Dictionary) -> void:
	for node_path in snapshot:
		# Try to find the node in the current scene
		var node = get_node_or_null(node_path)
		
		# If the node exists (Player, Boxes, Managers), restore it
		if node and node.has_method("restore_data"):
			node.restore_data(snapshot[node_path])
