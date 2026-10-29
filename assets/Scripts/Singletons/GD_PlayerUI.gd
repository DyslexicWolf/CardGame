extends CanvasLayer

signal ui_changed(new_ui_state: State)
@warning_ignore("unused_signal")
signal entered_combat()
@warning_ignore("unused_signal")
signal exited_combat()

@export var initial_state: State

var current_state: State
var states: Dictionary = { }


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transitioned)

	if initial_state:
		initial_state._enter()
		current_state = initial_state


func _process(delta: float) -> void:
	if current_state:
		current_state._state_process(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state._state_physics_process(delta)


func _on_child_transitioned(state: State, new_state_name: String) -> void:
	if state != current_state:
		return

	change_state(new_state_name)


func change_state(new_state_name: String) -> void:
	var new_state: State = states.get(new_state_name.to_lower())

	if new_state == null or new_state == current_state:
		return

	if current_state:
		current_state._exit()

	current_state = new_state
	current_state._enter()
	ui_changed.emit(current_state)
