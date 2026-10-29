class_name LootUIState
extends State

var loot_ui_state: LootUIState


func _ready() -> void:
	set_process_unhandled_input(false)
	loot_ui_state = self


func _unhandled_input(event: InputEvent) -> void:
	if not can_change_state:
		return

	get_viewport().set_input_as_handled()
	if event.is_action_pressed("CloseUI"):
		transitioned.emit(self, "HUDState")
	elif event.is_action_pressed("Inventory"):
		transitioned.emit(self, "InventoryUIState")


func _enter() -> void:
	set_process_unhandled_input(true)
	get_tree().paused = false
	loot_ui_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	set_process_unhandled_input(false)
	can_change_state = false
	loot_ui_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass
