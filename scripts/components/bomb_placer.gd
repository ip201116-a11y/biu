extends Node2D

@export var bomb_scene: PackedScene
@export var tile_size: int = 16
@export var max_bombs: int = 1 # Cap for existing bombs

# We need a dedicated raycast for placing to avoid messing with the player's movement ray
var ray: RayCast2D
var facing_direction: Vector2 = Vector2.DOWN

var active_bombs: Array[Node] = [] # Track placed bombs

func _ready() -> void:
	# Create a RayCast2D dynamically for this component
	ray = RayCast2D.new()
	ray.enabled = false # We only force update it
	add_child(ray)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			if active_bombs.size() < max_bombs:
				try_place_bomb()
			else:
				print("Bomb limit reached!")
		
		elif event.keycode == KEY_X:
			explode_all_bombs()

func update_direction(new_dir: Vector2) -> void:
	facing_direction = new_dir
	queue_redraw() # Redraw the indicator

func try_place_bomb() -> void:
	var player = get_parent()
	
	# Safety check: Don't place if player is moving or scene isn't set
	if not bomb_scene or (player.get("is_moving") and player.is_moving):
		return

	# Configure Raycast to check the tile in front
	# We assume the parent (Player) is centered on the tile
	ray.position = Vector2.ZERO
	ray.target_position = facing_direction * tile_size
	
	# Check against Walls (2) and Boxes/Bombs (4)
	# (These values match the Player's exported flags)
	ray.collision_mask = 2 + 4 
	ray.force_raycast_update()
	
	if not ray.is_colliding():
		spawn_bomb()
	else:
		print("Blocked! Cannot place bomb.")

func spawn_bomb() -> void:
	var new_bomb = bomb_scene.instantiate()
	
	# Calculate global position for the bomb
	# We use the parent's position + offset
	var target_pos = global_position + (facing_direction * tile_size)
	new_bomb.global_position = target_pos
	
	# Track the bomb
	active_bombs.append(new_bomb)
	
	# Listen for when the bomb is removed (exploded or deleted) to update our count
	new_bomb.tree_exiting.connect(_on_bomb_removed.bind(new_bomb))
	
	# Add to the Level (Player's parent) so it doesn't move attached to the player
	get_parent().get_parent().add_child(new_bomb)
	
	# Update indicator immediately
	queue_redraw()

func explode_all_bombs() -> void:
	for bomb in active_bombs:
		if is_instance_valid(bomb) and bomb.has_method("explode"):
			bomb.explode()
	# The list will clear itself via the _on_bomb_removed signal connection

func _on_bomb_removed(bomb: Node) -> void:
	if bomb in active_bombs:
		active_bombs.erase(bomb)
		queue_redraw()

func _draw() -> void:
	# VISUAL INDICATOR
	# Red = Ready to place
	# Gray = Limit reached
	var color = Color(1, 0, 0, 0.4)
	if active_bombs.size() >= max_bombs:
		color = Color(0.2, 0.2, 0.2, 0.4)
		
	var size = Vector2(tile_size, tile_size)
	
	# Offset to draw centered relative to the direction
	# (Assuming this node is at 0,0 relative to player center)
	var draw_pos = (facing_direction * tile_size) - (size / 2.0)
	
	draw_rect(Rect2(draw_pos, size), color, false, 2.0)
