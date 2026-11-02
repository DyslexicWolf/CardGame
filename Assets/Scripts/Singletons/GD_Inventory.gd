extends Node

signal card_added_to_deck(box_index: int, card: CardResource)
signal card_removed_from_deck(box_index: int)
signal cards_changed

enum Zone {
	DECK,
	INVENTORY,
}

var deck_cards: Array[CardResource]
var inventory_cards: Array[CardResource]
var _loadout_applied := false


func _init() -> void:
	deck_cards.resize(6)
	inventory_cards.resize(4)


func add_card_to_deck(card: CardResource, box_index: int) -> void:
	var new_card := card.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CardResource
	_set_slot(Zone.DECK, box_index, new_card)
	cards_changed.emit()


func add_card_to_inventory(card: CardResource, box_index: int) -> void:
	var new_card := card.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CardResource
	_set_slot(Zone.INVENTORY, box_index, new_card)
	cards_changed.emit()


func remove_card_from_deck(box_index: int) -> void:
	_set_slot(Zone.DECK, box_index, null)
	cards_changed.emit()


func remove_card_from_inventory(box_index: int) -> void:
	_set_slot(Zone.INVENTORY, box_index, null)
	cards_changed.emit()


## Moves a card between slots. to_index == -1 means "first empty slot".
## If the target slot is occupied, the two cards swap.
func move_card(from_zone: Zone, from_index: int, to_zone: Zone, to_index := -1) -> bool:
	var source := _zone_array(from_zone)
	var target := _zone_array(to_zone)
	var moving := source[from_index]
	if moving == null:
		return false
	if to_index == -1:
		to_index = target.find(null)
	if to_index == -1:
		return false
	if from_zone == to_zone and from_index == to_index:
		return false

	var displaced := target[to_index]
	_set_slot(from_zone, from_index, displaced)
	_set_slot(to_zone, to_index, moving)
	cards_changed.emit()
	return true


func _zone_array(zone: Zone) -> Array[CardResource]:
	return deck_cards if zone == Zone.DECK else inventory_cards


func _set_slot(zone: Zone, index: int, card: CardResource) -> void:
	_zone_array(zone)[index] = card
	if zone == Zone.DECK:
		if card:
			card_added_to_deck.emit(index, card)
		else:
			card_removed_from_deck.emit(index)


func apply_loadout(loadout: StartingLoadout) -> void:
	if _loadout_applied:
		return
	_loadout_applied = true
	_fill(deck_cards, loadout.deck_cards)
	_fill(inventory_cards, loadout.inventory_cards)
	cards_changed.emit()


func _fill(target: Array[CardResource], source: Array[CardResource]) -> void:
	if source.size() > target.size():
		push_warning(
			"Loadout has %d cards but only %d slots; extras ignored."
			% [source.size(), target.size()]
		)
	for i in mini(source.size(), target.size()):
		target[i] = source[i].duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as CardResource
