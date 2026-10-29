extends Node

signal card_added_to_deck(box_index: int, card: CardResource)
signal card_removed_from_deck(box_index: int)

var deck_cards: Array[CardResource]
var inventory_cards: Array[CardResource]


func _init() -> void:
	deck_cards.resize(6)
	inventory_cards.resize(4)


func add_card_to_deck(card: CardResource, box_index: int) -> void:
	var new_card := card.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	deck_cards[box_index] = new_card
	card_added_to_deck.emit(box_index, new_card)


func add_card_to_inventory(card: CardResource, box_index: int) -> void:
	var new_card := card.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	inventory_cards[box_index] = new_card


func remove_card_from_deck(box_index: int) -> void:
	deck_cards[box_index] = null
	card_removed_from_deck.emit(box_index)


func remove_card_from_inventory(box_index: int) -> void:
	inventory_cards[box_index] = null
