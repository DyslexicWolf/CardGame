class_name StartScreenUIState
extends State

var start_screen_ui_state: StartScreenUIState


func _ready() -> void:
	start_screen_ui_state = self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("CloseUI") or event.is_action_pressed("Pause"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "HUDState")


func _enter() -> void:
	get_tree().paused = false
	start_screen_ui_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	can_change_state = false
	start_screen_ui_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass
