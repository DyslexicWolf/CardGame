class_name PauseUIState
extends State

var pause_ui_state: PauseUIState


func _ready() -> void:
	set_process_unhandled_input(false)
	pause_ui_state = self


func _unhandled_input(event: InputEvent) -> void:
	if not can_change_state:
		return

	if event.is_action_pressed("CloseUI") or event.is_action_pressed("Pause"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "HUDState")


func _enter() -> void:
	set_process_unhandled_input(true)
	get_tree().paused = false
	pause_ui_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	set_process_unhandled_input(true)
	can_change_state = false
	pause_ui_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass


func _on_resume_button_pressed() -> void:
	transitioned.emit(self, "HUDState")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
