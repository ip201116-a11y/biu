# hi guys sorry for improper grammar hahaha :tired:
extends Button

const scene_first = "res://scenes/tests/test.tscn" # the first scene (rn its just test)

# CHANGES TO THE TEST THING CAN BE CHANGED LATER HAHAHAHAHAHNA 
func _on_pressed() -> void:
	get_tree().change_scene_to_file(scene_first)
