class_name CombatUIState
extends State

signal end_turn_requested

@export var end_turn_button: Button
@export var player_hand: PlayerHand

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
	if _is_pause(PlayerUI.previous_state):
		return # resuming: keep the current hand and deck
	PlayerUI.entered_combat.emit()
	player_hand.rebuild_deck()


func _exit() -> void:
	if not _is_pause(PlayerUI.next_state):
		PlayerUI.exited_combat.emit()
	set_process_unhandled_input(false)
	can_change_state = false
	combat_ui_state.hide()


func _on_end_turn_button_pressed() -> void:
	end_turn_requested.emit()


func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled


func _is_pause(state: State) -> bool:
	return state is PauseUIState
