@tool
extends Node

# Add your wall scene here
const SCENE_MAPPING = {
	"Box": "res://scenes/prefabs/box.tscn",
	"Wall": "res://scenes/prefabs/wall.tscn",
	"Detector": "res://scenes/prefabs/door_detector.tscn",
	"Door": "res://scenes/prefabs/door.tscn"
}

func post_import(entity_layer: LDTKEntityLayer) -> LDTKEntityLayer:
	var entities: Array = entity_layer.entities
	var scene_root = entity_layer.owner

	for entity in entities:
		if entity.identifier in SCENE_MAPPING:
			var scene_path = SCENE_MAPPING[entity.identifier]
			var packed_scene = load(scene_path)
			
			if packed_scene:
				var new_node = packed_scene.instantiate()
				new_node.position = entity.position
				
				# REFACTORED: Delegate field import to the object itself
				if new_node.has_method("import_ldtk_fields"):
					new_node.import_ldtk_fields(entity.fields)
				
				new_node.scale = entity.size / 16;
				

				entity_layer.add_child(new_node)
				new_node.owner = scene_root
				
				print("Mapped %s to %s" % [entity.identifier, new_node.name])
			else:
				push_warning("Could not load scene at path: %s" % scene_path)

	return entity_layer
