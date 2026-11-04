class_name SpellRow
extends HBoxContainer

## One spell: a spell circle slot followed by rune slots, resolved left to right.

@export var circle_slot: RowSlot
## Left to right. The spell circle's max_runes decides how many of these are unlocked.
@export var rune_slots: Array[RowSlot] = []


func _ready() -> void:
	refresh_locks()


func get_circle_card() -> BaseCard:
	return circle_slot.card if circle_slot else null


func get_circle() -> SpellCircleResource:
	var card := get_circle_card()
	return card.card_resource as SpellCircleResource if card else null


## Slotted rune cards, left to right, empty slots skipped.
func get_rune_cards() -> Array[BaseCard]:
	var cards: Array[BaseCard] = []
	for slot in rune_slots:
		if slot.card:
			cards.append(slot.card)
	return cards


func get_rune_resources() -> Array[RuneResource]:
	var runes: Array[RuneResource] = []
	for card in get_rune_cards():
		runes.append(card.card_resource as RuneResource)
	return runes


func all_slots() -> Array[RowSlot]:
	var slots: Array[RowSlot] = [circle_slot]
	slots.append_array(rune_slots)
	return slots


func allowed_rune_slots() -> int:
	var circle := get_circle()
	return mini(circle.max_runes, rune_slots.size()) if circle else 0


## Mana this row costs right now (0 without a spell circle).
func get_mana_cost() -> int:
	var circle := get_circle()
	return circle.get_mana_cost(get_rune_resources()) if circle else 0


func refresh_locks() -> void:
	var allowed := allowed_rune_slots()
	for i in rune_slots.size():
		rune_slots[i].locked = i >= allowed
