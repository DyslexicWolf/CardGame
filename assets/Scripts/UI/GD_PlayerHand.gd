class_name PlayerHand
extends Control

signal card_played(card: BaseCard, global_pos: Vector2) # hook for future mechanics

@export var max_hand_size := 8
@export var draw_amount := 5
@export var card_scene: PackedScene
@export var draw_button: Button

@export_group("Fan")
##Radius of the arc
@export var fan_radius := 900.0
##Arc distance between adjacent cards
@export var card_spacing := 110.0
##Total spread limit
@export var max_fan_angle := deg_to_rad(40.0)
##Pushes the arc origin up/down
@export var fan_center_offset := 0.0

@export_group("Draw animation")
@export var draw_duration := 0.22
@export var draw_stagger := 0.08
@export var relayout_duration := 0.2

@export_group("RowSlots")
@export var row_slots: Array[RowSlot] = []

var _drag_origin_slot: RowSlot = null
var _hand_cards: Array[BaseCard] = []
var _deck: Array[CardResource] = []
var _player_hand: Control
var _drag_origin_index := -1


func _ready() -> void:
	_player_hand = self
	rebuild_deck()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)


func draw_cards(count: int) -> void:
	var amount := mini(count, mini(max_hand_size - _hand_cards.size(), _deck.size()))
	if amount <= 0:
		return

	var new_cards: Array[BaseCard] = []
	for i in amount:
		var card := _spawn_card(_deck.pop_back())
		_hand_cards.append(card)
		new_cards.append(card)

	_layout(new_cards)


func remove_card(card: BaseCard) -> void:
	_hand_cards.erase(card)
	card.dispose()
	_layout()


func clear_hand() -> void:
	for card in _hand_cards:
		card.dispose()
	_hand_cards.clear()


func rebuild_deck() -> void:
	_deck.clear()
	for c in Inventory.deck_cards:
		if c != null:
			_deck.append(c)
	_deck.shuffle()


## Cards in slot order (top to bottom). Empty slots are null so indices stay meaningful.
func get_row_cards() -> Array[BaseCard]:
	var slots := row_slots.duplicate()
	slots.sort_custom(
		func(a: RowSlot, b: RowSlot) -> bool:
			return a.global_position.y < b.global_position.y,
	)
	var cards: Array[BaseCard] = []
	for slot: RowSlot in slots:
		cards.append((slot as RowSlot).card)
	return cards


func _on_draw_pressed() -> void:
	draw_cards(draw_amount)


func _spawn_card(resource: CardResource) -> BaseCard:
	var card: BaseCard = card_scene.instantiate()
	add_child(card)
	card.setup(resource)
	card.drag_started.connect(_on_card_drag_started)
	card.drag_released.connect(_on_card_drag_released)
	card.apply_visual(_spawn_position(card), 0.0, Vector2.ONE * 0.5)
	return card


func _spawn_position(card: BaseCard) -> Vector2:
	return Vector2(size.x * 0.5, -size.y) - card.size * 0.5


func _fan_slot(index: int, total: int, card_size: Vector2) -> Array:
	var step := card_spacing / fan_radius
	if total > 1:
		step = minf(step, max_fan_angle / float(total - 1))
	var angle := (index - (total - 1) * 0.5) * step

	var origin := Vector2(size.x * 0.5, size.y + fan_radius + fan_center_offset)
	var pos := origin + Vector2(sin(angle), -cos(angle)) * fan_radius
	return [pos - card_size * 0.5, angle]


func _layout(new_cards: Array[BaseCard] = []) -> void:
	var total := _hand_cards.size()
	var new_index := 0
	for i in total:
		var card := _hand_cards[i]
		if card.is_dragging:
			continue
		var slot := _fan_slot(i, total, card.size)
		card.home_position = slot[0]
		card.home_rotation = slot[1]
		card.home_z = i

		if card in new_cards:
			card.go_home(draw_duration, new_index * draw_stagger)
			new_index += 1
		else:
			card.go_home(relayout_duration)

# Replace _on_card_drag_released with everything below


func _on_card_drag_started(card: BaseCard) -> void:
	_drag_origin_slot = _slot_holding(card)
	_drag_origin_index = _hand_cards.find(card)
	card.is_slotted = false
	if _drag_origin_slot:
		_drag_origin_slot.clear()

	# The card leaves the hand now, so the fan closes the gap immediately.
	_hand_cards.erase(card)
	_layout()


## Runs after the drag ends. Decides where the card goes based on the mouse position.
func _on_card_drag_released(card: BaseCard, global_pos: Vector2) -> void:
	card_played.emit(card, global_pos)

	var returned := false
	var slot := _slot_at(global_pos)
	if slot:
		var occupant := slot.card
		if occupant and occupant != card:
			if _drag_origin_slot:
				_put_in_slot(occupant, _drag_origin_slot)
			else:
				_return_to_hand(occupant)
		_put_in_slot(card, slot)
	else:
		_return_to_hand(card, _drag_origin_index)
		returned = true

	_drag_origin_slot = null
	_drag_origin_index = -1
	_layout()
	if returned:
		card.fly_home(relayout_duration) # home values were just set by _layout


func _slot_at(global_pos: Vector2) -> RowSlot:
	for slot in row_slots:
		if slot.get_global_rect().has_point(global_pos):
			return slot
	return null


func _put_in_slot(card: BaseCard, slot: RowSlot) -> void:
	_hand_cards.erase(card)
	slot.assign(card)
	card.is_slotted = true
	card.home_position = _slot_home_position(slot, card)
	card.home_rotation = 0.0
	card.home_z = BaseCard.SLOT_Z
	card.go_home(relayout_duration)


## index = -1 appends. Otherwise the card goes back to where it was in the fan.
func _return_to_hand(card: BaseCard, index := -1) -> void:
	card.is_slotted = false
	if card in _hand_cards:
		return
	if index >= 0 and index <= _hand_cards.size():
		_hand_cards.insert(index, card)
	else:
		_hand_cards.append(card)


func _slot_holding(card: BaseCard) -> RowSlot:
	for slot in row_slots:
		if slot.card == card:
			return slot
	return null


## Slot center in this hand's local space (cards are children of the hand).
func _slot_home_position(slot: RowSlot, card: BaseCard) -> Vector2:
	var center := slot.get_global_rect().get_center()
	var local := get_global_transform().affine_inverse() * center
	return local - card.size * 0.5


## Fades out and disposes every card in the row slots, then empties the slots.
func discard_row_cards(fade_duration := 0.25) -> void:
	var any := false
	for slot in row_slots:
		var card := slot.card
		if card == null:
			continue
		any = true
		slot.clear()
		_hand_cards.erase(card)
		var t := card.create_tween()
		t.tween_property(card, "modulate:a", 0.0, fade_duration)
		t.finished.connect(card.dispose)
	if any and fade_duration > 0.0:
		await get_tree().create_timer(fade_duration).timeout
