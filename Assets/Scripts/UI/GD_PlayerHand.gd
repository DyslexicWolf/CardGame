class_name PlayerHand
extends Control

signal card_played(card: BaseCard, global_pos: Vector2) # hook for future mechanics

signal placement_rejected(card: BaseCard, reason: String)

@export var draw_amount := 5
@export var draw_button: Button
@export var mana_pool: ManaPool

@export_group("Hands")
## Holds the spell circle cards.
@export var circle_fan: HandFan
## Holds the rune cards.
@export var rune_fan: HandFan

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
var _deck: Array[CardResource] = []
var _discard: Array[CardResource] = []
var _drag_origin_index := -1


func _ready() -> void:
	rebuild_deck()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)


func draw_cards(count: int) -> void:
	var new_cards: Array[BaseCard] = []
	for resource in _draw_resources(count):
		var card := _spawn_card(resource)
		_fan_for(resource).cards.append(card)
		new_cards.append(card)

	if not new_cards.is_empty():
		_layout(new_cards)


func remove_card(card: BaseCard) -> void:
	_fan_for(card.card_resource).cards.erase(card)
	card.dispose()
	_layout()


func clear_hand() -> void:
	for fan in _fans():
		for card in fan.cards:
			card.dispose()
		fan.cards.clear()


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
		var index := _next_drawable_index(drawn)
		if index == -1:
			_reshuffle_discard_into_deck()
			index = _next_drawable_index(drawn)
			if index == -1:
				break # every remaining card's hand is full, or all cards are in hands or spell rows
		drawn.append(_deck.pop_at(index))
	_ensure_spell_circle(drawn, amount)
	return drawn


## Top-most deck card whose hand still has room, -1 if there is none.
func _next_drawable_index(drawn: Array[CardResource]) -> int:
	for i in range(_deck.size() - 1, -1, -1):
		var fan := _fan_for(_deck[i])
		var incoming := drawn.filter(
			func(c: CardResource) -> bool:
				return _fan_for(c) == fan,
		).size()
		if fan.get_room() > incoming:
			return i
	return -1


## The circle hand always holds a spell circle after drawing, as long as one is left in the deck or discard pile.
## It takes the place of the last drawn card, which goes back on top of the deck.
func _ensure_spell_circle(drawn: Array[CardResource], amount: int) -> void:
	if amount <= 0 or drawn.any(_is_spell_circle) or not circle_fan.cards.is_empty():
		return

	var index := _deck.find_custom(_is_spell_circle)
	if index == -1:
		_reshuffle_discard_into_deck()
		index = _deck.find_custom(_is_spell_circle)
		if index == -1:
			return # every spell circle is already in a spell row
	var circle: CardResource = _deck.pop_at(index)
	if drawn.size() >= amount:
		_deck.append(drawn.pop_back())
	drawn.append(circle)


func _is_spell_circle(resource: CardResource) -> bool:
	return resource is SpellCircleResource


## Spell rows in cast order (top to bottom).
func get_spell_rows() -> Array[SpellRow]:
	return spell_rows


func _on_draw_pressed() -> void:
	draw_cards(draw_amount)


func _fans() -> Array[HandFan]:
	return [circle_fan, rune_fan]


func _fan_for(resource: CardResource) -> HandFan:
	return rune_fan if resource is RuneResource else circle_fan


func _spawn_card(resource: CardResource) -> BaseCard:
	var card := CardFactory.create(resource)
	var fan := _fan_for(resource)
	fan.add_child(card)
	card.drag_started.connect(_on_card_drag_started)
	card.drag_released.connect(_on_card_drag_released)
	card.apply_visual(_spawn_position(fan, card), 0.0, Vector2.ONE * 0.5)
	return card


func _spawn_position(fan: HandFan, card: BaseCard) -> Vector2:
	return Vector2(fan.size.x * 0.5, -fan.size.y) - card.size * 0.5


func _layout(new_cards: Array[BaseCard] = []) -> void:
	for fan in _fans():
		_layout_fan(fan, new_cards)


func _layout_fan(fan: HandFan, new_cards: Array[BaseCard]) -> void:
	var total := fan.cards.size()
	var new_index := 0
	for i in total:
		var card := fan.cards[i]
		if card.is_dragging:
			continue
		var slot := fan.get_card_slot(i, total, card.size)
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
	var fan := _fan_for(card.card_resource)
	_drag_origin_index = fan.cards.find(card)
	card.is_slotted = false
	card.home_scale = 1.0

	if _drag_origin_slot:
		_drag_origin_slot.clear()
		var row := _row_of(_drag_origin_slot)
		if card.card_resource is SpellCircleResource:
			_return_runes_to_hand(row) # pulling a spell circle out sends its runes back
		row.refresh_locks()

	fan.cards.erase(card)
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
	_fan_for(card.card_resource).cards.erase(card)
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
	var cards := _fan_for(card.card_resource).cards
	if card in cards:
		return
	if index >= 0 and index <= cards.size():
		cards.insert(index, card)
	else:
		cards.append(card)


func _slot_holding(card: BaseCard) -> RowSlot:
	for row in spell_rows:
		for slot in row.all_slots():
			if slot.card == card:
				return slot
	return null


## Slot center in the local space of the card's fan (cards are children of their fan).
## Cards scale around their center, so this stays centered at any slotted_scale.
func _slot_home_position(slot: RowSlot, card: BaseCard) -> Vector2:
	var center := slot.get_global_rect().get_center()
	var local := _fan_for(card.card_resource).get_global_transform().affine_inverse() * center
	return local - card.size * 0.5
