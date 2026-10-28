class_name InventoryUIState
extends State

var inventory_ui_state: InventoryUIState


func _ready() -> void:
	inventory_ui_state = self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("CloseUI") or event.is_action_pressed("Inventory"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "HUDState")


func _enter() -> void:
	get_tree().paused = false
	inventory_ui_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	can_change_state = false
	inventory_ui_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass
