class_name State
extends Node

@warning_ignore("unused_signal")
signal transitioned(state: State, new_state_name: String)

var can_change_state: bool


func input_delay() -> void:
	can_change_state = false
	await get_tree().process_frame
	can_change_state = true


func _enter() -> void:
	pass


func _exit() -> void:
	pass


func _state_process(_delta: float) -> void:
	pass


func _state_physics_process(_delta: float) -> void:
	pass
