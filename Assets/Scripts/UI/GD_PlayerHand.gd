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

@export_group("SpellRows")
## Top to bottom. This is also the order the spells are cast in.
@export var spell_rows: Array[SpellRow] = []
## Scale of a card sitting in a spell row slot.
@export var slotted_scale := 0.5

var _drag_origin_slot: RowSlot = null
var _hand_cards: Array[BaseCard] = []
var _deck: Array[CardResource] = []
var _discard: Array[CardResource] = []
var _player_hand: Control
var _drag_origin_index := -1


func _ready() -> void:
	_player_hand = self
	rebuild_deck()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)


func draw_cards(count: int) -> void:
	var new_cards: Array[BaseCard] = []
	for resource in _draw_resources(mini(count, max_hand_size - _hand_cards.size())):
		var card := _spawn_card(resource)
		_hand_cards.append(card)
		new_cards.append(card)

	if not new_cards.is_empty():
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
	_discard.clear()
	for c in Inventory.deck_cards:
		if c != null:
			_deck.append(c)
	_deck.shuffle()


func _reshuffle_discard_into_deck() -> void:
	_deck.append_array(_discard)
	_discard.clear()
	_deck.shuffle()


func _draw_resources(amount: int) -> Array[CardResource]:
	var drawn: Array[CardResource] = []
	for i in amount:
		if _deck.is_empty():
			_reshuffle_discard_into_deck()
			if _deck.is_empty():
				break # every card is already in hand or in a spell row
		drawn.append(_deck.pop_back())
	_ensure_spell_circle(drawn, amount)
	return drawn


## The hand always holds a spell circle after drawing, as long as one is left in the deck or discard pile.
## It takes the place of the last drawn card, which goes back on top of the deck.
func _ensure_spell_circle(drawn: Array[CardResource], room: int) -> void:
	if room <= 0 or drawn.any(_is_spell_circle) or _hand_cards.any(
		func(c: BaseCard) -> bool:
			return _is_spell_circle(c.card_resource),
	):
		return

	var index := _deck.find_custom(_is_spell_circle)
	if index == -1:
		_reshuffle_discard_into_deck()
		index = _deck.find_custom(_is_spell_circle)
		if index == -1:
			return # every spell circle is already in a spell row
	var circle: CardResource = _deck.pop_at(index)
	if drawn.size() >= room:
		_deck.append(drawn.pop_back())
	drawn.append(circle)


func _is_spell_circle(resource: CardResource) -> bool:
	return resource is SpellCircleResource


## Spell rows in cast order (top to bottom).
func get_spell_rows() -> Array[SpellRow]:
	return spell_rows


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
	card.home_scale = 1.0

	if _drag_origin_slot:
		_drag_origin_slot.clear()
		var row := _row_of(_drag_origin_slot)
		if card.card_resource is SpellCircleResource:
			_return_runes_to_hand(row) # pulling a spell circle out sends its runes back
		row.refresh_locks()

	_hand_cards.erase(card)
	_refresh_mana()
	_layout()


func _on_card_drag_released(card: BaseCard, global_pos: Vector2) -> void:
	card_played.emit(card, global_pos)

	var placed := false
	var slot := _slot_at(global_pos)
	if slot:
		if card.card_resource is SpellCircleResource:
			placed = _try_place_circle(card, slot)
		elif card.card_resource is RuneResource:
			placed = _try_place_rune(card, slot)

	if not placed:
		_return_to_hand(card, _drag_origin_index)

	_drag_origin_slot = null
	_drag_origin_index = -1
	_refresh_mana()
	_layout()
	if not placed:
		card.fly_home(relayout_duration)


func _try_place_circle(card: BaseCard, slot: RowSlot) -> bool:
	if not slot.accepts(card.card_resource):
		return _reject(card, "Spell circles go in the first slot of a row")
	var row := _row_of(slot)
	var circle := card.card_resource as SpellCircleResource
	var kept_slots := mini(circle.max_runes, row.rune_slots.size())
	var total := _committed_mana() - row.get_mana_cost() + circle.get_mana_cost(_runes_in(row, kept_slots))
	if not _can_afford(total):
		return _reject(card, "Not enough mana")

	var occupant := slot.card
	if occupant and occupant != card:
		# Replaced spell circle goes back to the hand, its runes stay if the new circle has room.
		slot.clear()
		_return_to_hand(occupant)
	_put_in_slot(card, slot)
	_return_runes_to_hand(row, kept_slots)
	row.refresh_locks()
	return true


func _try_place_rune(card: BaseCard, slot: RowSlot) -> bool:
	if not slot.accepts(card.card_resource):
		return _reject(card, "Runes go after a spell circle")
	var row := _row_of(slot)
	var circle := row.get_circle()
	if circle == null:
		return _reject(card, "Runes need a spell circle")
	if slot.locked:
		return _reject(card, "This spell circle only holds %d runes" % circle.max_runes)

	var occupant := slot.card
	var runes := row.get_rune_resources()
	if occupant:
		runes.erase(occupant.card_resource)
	runes.append(card.card_resource as RuneResource)
	var total := _committed_mana() - row.get_mana_cost() + circle.get_mana_cost(runes)
	if not _can_afford(total):
		return _reject(card, "Not enough mana")

	if occupant and occupant != card:
		slot.clear()
		_return_to_hand(occupant)
	_put_in_slot(card, slot)
	return true


func _reject(card: BaseCard, reason: String) -> bool:
	placement_rejected.emit(card, reason)
	return false

# --- Mana helpers ---


func _committed_mana() -> int:
	var total := 0
	for row in spell_rows:
		total += row.get_mana_cost()
	return total


func _can_afford(total: int) -> bool:
	return mana_pool == null or total <= mana_pool.max_mana


func _refresh_mana() -> void:
	if mana_pool:
		mana_pool.set_committed(_committed_mana())

# --- Spell row helpers ---


func _row_of(slot: RowSlot) -> SpellRow:
	for row in spell_rows:
		if slot in row.all_slots():
			return row
	return null


## Runes in the first `slot_count` rune slots of a row.
func _runes_in(row: SpellRow, slot_count: int) -> Array[RuneResource]:
	var runes: Array[RuneResource] = []
	for i in mini(slot_count, row.rune_slots.size()):
		var rune_card := row.rune_slots[i].card
		if rune_card:
			runes.append(rune_card.card_resource as RuneResource)
	return runes


## Sends the runes in rune slots from `from_index` onwards back to the hand.
func _return_runes_to_hand(row: SpellRow, from_index := 0) -> void:
	for i in range(from_index, row.rune_slots.size()):
		var slot := row.rune_slots[i]
		if slot.card:
			_return_to_hand(slot.card)
			slot.clear()


func _fade_and_dispose(card: BaseCard, duration: float) -> void:
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 0.0, duration)
	t.finished.connect(card.dispose)


func discard_row_cards(fade_duration := 0.25) -> void:
	var any := false
	for row in spell_rows:
		for slot in row.all_slots():
			var card := slot.card
			if card == null:
				continue
			any = true
			slot.clear()
			_hand_cards.erase(card)
			_discard.append(card.card_resource)
			_fade_and_dispose(card, fade_duration)
		row.refresh_locks()
	_refresh_mana()
	if any and fade_duration > 0.0:
		await get_tree().create_timer(fade_duration).timeout


func _slot_at(global_pos: Vector2) -> RowSlot:
	for row in spell_rows:
		for slot in row.all_slots():
			if slot.get_global_rect().has_point(global_pos):
				return slot
	return null


func _put_in_slot(card: BaseCard, slot: RowSlot) -> void:
	_hand_cards.erase(card)
	slot.assign(card)
	card.is_slotted = true
	card.home_scale = slotted_scale
	card.home_position = _slot_home_position(slot, card)
	card.home_rotation = 0.0
	card.home_z = BaseCard.SLOT_Z
	card.go_home(relayout_duration)


## index = -1 appends. Otherwise the card goes back to where it was in the fan.
func _return_to_hand(card: BaseCard, index := -1) -> void:
	card.is_slotted = false
	card.home_scale = 1.0
	if card in _hand_cards:
		return
	if index >= 0 and index <= _hand_cards.size():
		_hand_cards.insert(index, card)
	else:
		_hand_cards.append(card)


func _slot_holding(card: BaseCard) -> RowSlot:
	for row in spell_rows:
		for slot in row.all_slots():
			if slot.card == card:
				return slot
	return null


## Slot center in this hand's local space (cards are children of the hand).
## Cards scale around their center, so this stays centered at any slotted_scale.
func _slot_home_position(slot: RowSlot, card: BaseCard) -> Vector2:
	var center := slot.get_global_rect().get_center()
	var local := get_global_transform().affine_inverse() * center
	return local - card.size * 0.5
