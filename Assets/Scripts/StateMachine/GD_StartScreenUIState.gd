class_name StartScreenUIState
extends State

var start_screen_ui_state: StartScreenUIState


func _ready() -> void:
	set_process_unhandled_input(false)
	start_screen_ui_state = self


func _unhandled_input(event: InputEvent) -> void:
	if not can_change_state:
		return

	get_viewport().set_input_as_handled()
	if event.is_action_pressed("Pause"):
		transitioned.emit(self, "PauseUIState")


func _enter() -> void:
	set_process_unhandled_input(true)
	get_tree().paused = false
	start_screen_ui_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	set_process_unhandled_input(false)
	can_change_state = false
	start_screen_ui_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass
