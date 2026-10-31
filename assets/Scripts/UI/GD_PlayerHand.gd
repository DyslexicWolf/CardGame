class_name PlayerHand
extends Control

signal card_played(card: BaseCard, global_pos: Vector2) # hook for future mechanics

signal placement_rejected(card: BaseCard, reason: String)

@export var max_hand_size := 8
@export var draw_amount := 5
@export var card_scene: PackedScene
@export var draw_button: Button
@export var mana_pool: ManaPool

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

@export_group("Sigils")
## Where the first attached spell sigil sits relative to its spell circle. Tune to your card size.
@export var sigil_start_offset := Vector2(200, 0)
@export var sigil_step := Vector2(0, 60)

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


func _on_card_drag_started(card: BaseCard) -> void:
	_drag_origin_slot = _slot_holding(card)
	_drag_origin_index = _hand_cards.find(card)
	card.is_slotted = false

	if _drag_origin_slot:
		_drag_origin_slot.clear()
		_return_sigils_to_hand(card) # pulling a spell circle out sends its spell sigils back
	else:
		var owner_card := _circle_owning(card)
		if owner_card:
			owner_card.attached_sigils.erase(card)
			_layout_sigils(owner_card)

	_hand_cards.erase(card)
	_refresh_mana()
	_layout()


func _on_card_drag_released(card: BaseCard, global_pos: Vector2) -> void:
	card_played.emit(card, global_pos)

	var placed := false
	var slot := _slot_at(global_pos)
	if slot:
		if card.card_resource is SpellSigilResource:
			placed = _try_attach_sigil(card, slot)
		elif card.card_resource is SpellCircleResource:
			placed = _try_place_circle(card, slot)

	if not placed:
		_return_to_hand(card, _drag_origin_index)

	_drag_origin_slot = null
	_drag_origin_index = -1
	_refresh_mana()
	_layout()
	if not placed:
		card.fly_home(relayout_duration)


func _try_place_circle(card: BaseCard, slot: RowSlot) -> bool:
	var circle := card.card_resource as SpellCircleResource
	var occupant := slot.card
	var total := _committed_mana() - _slot_cost(slot) + circle.get_mana_cost()
	if not _can_afford(total):
		return _reject(card, "Not enough mana")

	if occupant and occupant != card:
		# Replaced spell circle (and its spell sigils) go back to the hand.
		slot.clear()
		_return_sigils_to_hand(occupant)
		_return_to_hand(occupant)
	_put_in_slot(card, slot)
	return true


func _try_attach_sigil(card: BaseCard, slot: RowSlot) -> bool:
	var circle_card := slot.card
	if circle_card == null:
		return _reject(card, "Spell sigils need a spell circle")
	var circle := circle_card.card_resource as SpellCircleResource
	if circle_card.attached_sigils.size() >= circle.max_sigils:
		return _reject(card, "No free spell sigil slot")

	var sigils := circle_card.get_sigil_resources()
	sigils.append(card.card_resource as SpellSigilResource)
	var delta := circle.get_mana_cost(sigils) - _slot_cost(slot)
	if not _can_afford(_committed_mana() + delta):
		return _reject(card, "Not enough mana")

	circle_card.attached_sigils.append(card)
	card.is_slotted = true
	_layout_sigils(circle_card)
	return true


func _reject(card: BaseCard, reason: String) -> bool:
	placement_rejected.emit(card, reason)
	return false

# --- Mana helpers ---


func _slot_cost(slot: RowSlot) -> int:
	if slot.card == null:
		return 0
	var circle := slot.card.card_resource as SpellCircleResource
	return circle.get_mana_cost(slot.card.get_sigil_resources()) if circle else 0


func _committed_mana() -> int:
	var total := 0
	for slot in row_slots:
		total += _slot_cost(slot)
	return total


func _can_afford(total: int) -> bool:
	return mana_pool == null or total <= mana_pool.max_mana


func _refresh_mana() -> void:
	if mana_pool:
		mana_pool.set_committed(_committed_mana())

# --- Sigil helpers ---


func _circle_owning(sigil: BaseCard) -> BaseCard:
	for slot in row_slots:
		if slot.card and sigil in slot.card.attached_sigils:
			return slot.card
	return null


func _return_sigils_to_hand(circle_card: BaseCard) -> void:
	for sigil in circle_card.attached_sigils:
		_return_to_hand(sigil)
	circle_card.attached_sigils.clear()


func _layout_sigils(circle_card: BaseCard) -> void:
	for i in circle_card.attached_sigils.size():
		var sigil := circle_card.attached_sigils[i]
		sigil.home_position = circle_card.home_position + sigil_start_offset + sigil_step * i
		sigil.home_rotation = 0.0
		sigil.home_z = BaseCard.SLOT_Z + 1 + i
		sigil.go_home(relayout_duration)


func _fade_and_dispose(card: BaseCard, duration: float) -> void:
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 0.0, duration)
	t.finished.connect(card.dispose)


func discard_row_cards(fade_duration := 0.25) -> void:
	var any := false
	for slot in row_slots:
		var card := slot.card
		if card == null:
			continue
		any = true
		slot.clear()
		_hand_cards.erase(card)
		for sigil in card.attached_sigils:
			_fade_and_dispose(sigil, fade_duration)
		card.attached_sigils.clear()
		_fade_and_dispose(card, fade_duration)
	_refresh_mana()
	if any and fade_duration > 0.0:
		await get_tree().create_timer(fade_duration).timeout


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
