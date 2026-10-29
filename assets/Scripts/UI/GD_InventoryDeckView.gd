class_name InventoryDeckView
extends Control

signal card_drag_released(card: BaseCard, global_pos: Vector2, deck_index: int)

@export var card_scene: PackedScene

@export_group("Layout")
@export var min_visible_width := 36.0
@export var layout_duration := 0.2

@export_group("Hover")
@export var hover_lift := 14.0

var _cards: Array[BaseCard] = []
var _hovered_card: BaseCard


func _ready() -> void:
	resized.connect(_layout.bind(false))


## `slots` is Inventory.deck_cards (it can contain nulls). The slot index is kept per card.
func show_cards(slots: Array[CardResource]) -> void:
	_clear()
	for slot_index in slots.size():
		var resource := slots[slot_index]
		if resource == null:
			continue
		var card := card_scene.instantiate() as BaseCard
		add_child(card)
		card.size = card.get_combined_minimum_size()
		card.setup(resource)

		card.hover_lift = minf(hover_lift, (card.hover_scale - 1.0) * card.size.y * 0.45)
		card.hover_started.connect(_on_card_hover_started)
		card.hover_ended.connect(_on_card_hover_ended)
		card.drag_released.connect(_on_card_drag_released.bind(slot_index))
		_cards.append(card)
	_layout(false)


func return_card(card: BaseCard) -> void:
	card.go_home(layout_duration)


func _clear() -> void:
	for card in _cards:
		remove_child(card)
		card.dispose()
	_cards.clear()
	_hovered_card = null


func _layout(animate: bool) -> void:
	var count := _cards.size()
	if count == 0:
		return
	var card_size := _cards[0].size

	var step := card_size.x
	if count > 1:
		step = clampf((size.x - card_size.x) / (count - 1), min_visible_width, card_size.x)

	var total_width := card_size.x + step * (count - 1)
	var start := Vector2((size.x - total_width) * 0.5, (size.y - card_size.y) * 0.5)

	for i in count:
		var card := _cards[i]
		if card.is_dragging:
			continue
		card.home_position = start + Vector2(step * i, 0.0)
		card.home_rotation = 0.0
		card.home_z = i
		if animate:
			card.go_home(layout_duration)
		else:
			card.snap_home()


func _on_card_hover_started(card: BaseCard) -> void:
	_hovered_card = card
	move_child(card, -1)


func _on_card_hover_ended(card: BaseCard) -> void:
	if _hovered_card == card:
		_hovered_card = null
	_restore_order()
	if _hovered_card:
		move_child(_hovered_card, -1)


func _restore_order() -> void:
	for card in _cards:
		move_child(card, -1)


func _on_card_drag_released(card: BaseCard, global_pos: Vector2, deck_index: int) -> void:
	_hovered_card = null
	_restore_order()
	card_drag_released.emit(card, global_pos, deck_index)
