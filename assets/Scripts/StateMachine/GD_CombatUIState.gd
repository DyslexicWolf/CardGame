class_name CombatUIState
extends State

var combat_ui_state: CombatUIState


func _ready() -> void:
	set_process_unhandled_input(false)
	combat_ui_state = self


func _unhandled_input(event: InputEvent) -> void:
	if not can_change_state:
		return

	if event.is_action_pressed("CloseUI") or event.is_action_pressed("Pause"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "PauseUIState")


func _enter() -> void:
	set_process_unhandled_input(true)
	get_tree().paused = false
	combat_ui_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	set_process_unhandled_input(false)
	can_change_state = false
	combat_ui_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass
