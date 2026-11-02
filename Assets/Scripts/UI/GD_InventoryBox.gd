class_name InventoryBox
extends Control

signal card_drag_released(card: BaseCard, global_pos: Vector2, box: InventoryBox)

@export var card_scene: PackedScene

var box_index := -1
var _card: BaseCard


func _ready() -> void:
	resized.connect(_center_card)


func set_card(resource: CardResource) -> void:
	if _card:
		remove_child(_card)
		_card.dispose()
		_card = null
	if resource == null:
		return

	_card = card_scene.instantiate() as BaseCard
	add_child(_card)
	_card.size = _card.get_combined_minimum_size()
	_card.setup(resource)
	_card.hover_lift = 0.0
	_card.hover_scale = 1.08
	_card.drag_released.connect(_on_card_drag_released)
	_center_card()


func return_card() -> void:
	if _card:
		_card.go_home(0.2)


func _center_card() -> void:
	if _card == null or _card.is_dragging:
		return
	_card.home_position = (size - _card.size) * 0.5
	_card.home_rotation = 0.0
	_card.home_z = 0
	_card.snap_home()


func _on_card_drag_released(card: BaseCard, global_pos: Vector2) -> void:
	card_drag_released.emit(card, global_pos, self)
