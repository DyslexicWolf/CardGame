class_name StartScreen
extends Control

@export_file("*.tscn") var game_scene_path: String


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)
	PlayerUI.change_state("HUDState")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
