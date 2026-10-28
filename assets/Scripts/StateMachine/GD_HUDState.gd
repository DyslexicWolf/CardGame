class_name HUDState
extends State

var hud_state: HUDState


func _ready() -> void:
	hud_state = self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Inventory"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "InventoryUIState")
	elif event.is_action_pressed("Pause"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "PauseUIState")


func _enter() -> void:
	get_tree().paused = false
	hud_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	can_change_state = false
	hud_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass
