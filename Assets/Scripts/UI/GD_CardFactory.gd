class_name CardFactory
extends RefCounted

## Picks the card prefab that matches a card resource.

const SPELL_CIRCLE_CARD: PackedScene = preload("res://Assets/Prefabs/UI/PF_SpellCircleCard.tscn")
const RUNE_CARD: PackedScene = preload("res://Assets/Prefabs/UI/PF_RuneCard.tscn")


static func create(resource: CardResource) -> BaseCard:
	var scene := RUNE_CARD if resource is RuneResource else SPELL_CIRCLE_CARD
	var card := scene.instantiate() as BaseCard
	card.setup(resource)
	return card
