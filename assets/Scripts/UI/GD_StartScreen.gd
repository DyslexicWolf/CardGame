class_name StartScreen
extends Control

@export_file("*.tscn") var combat_scene_path: String


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(combat_scene_path)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
