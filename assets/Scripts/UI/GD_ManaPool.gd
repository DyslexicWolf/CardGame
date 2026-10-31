class_name ManaPool
extends TextureProgressBar

signal mana_changed(committed: int, max_mana: int)

@export var max_mana := 5:
	set(value):
		max_mana = value
		_refresh_bar()
		mana_changed.emit(committed, max_mana)

var committed := 0


func _ready() -> void:
	step = 1.0
	_refresh_bar()


func set_committed(_value: int) -> void:
	committed = _value
	_refresh_bar()
	mana_changed.emit(committed, max_mana)


func get_available() -> int:
	return max_mana - committed


## The bar shows the mana still available, so it drains as spell circles and spell sigils are placed.
func _refresh_bar() -> void:
	min_value = 0
	max_value = max_mana
	value = clampi(committed, 0, max_mana)
