class_name LootUIState
extends State

var loot_ui_state: LootUIState


func _ready() -> void:
	loot_ui_state = self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("CloseUI"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "HUDState")
	elif event.is_action_pressed("Inventory"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "InventoryUIState")


func _enter() -> void:
	get_tree().paused = false
	loot_ui_state.show()
	call_deferred("input_delay")


func _exit() -> void:
	can_change_state = false
	loot_ui_state.hide()


func _state_physics_process(_delta: float) -> void:
	pass
