class_name HUDState
extends State

var hud_state: HUDState


func _ready() -> void:
	set_process_unhandled_input(false)
	hud_state = self


func _unhandled_input(event: InputEvent) -> void:
	if not can_change_state:
		return

	get_viewport().set_input_as_handled()
	if event.is_action_pressed("Inventory"):
		transitioned.emit(self, "InventoryUIState")
	elif event.is_action_pressed("Pause"):
		transitioned.emit(self, "PauseUIState")


func _enter() -> void:
	set_process_unhandled_input(true)
	get_tree().paused = false
	hud_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	set_process_unhandled_input(false)
	can_change_state = false
	hud_state.hide()


func _on_start_combat_button_pressed() -> void:
	transitioned.emit(self, "CombatUIState")
