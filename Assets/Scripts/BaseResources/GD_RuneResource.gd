@tool
class_name RuneResource
extends CardResource

## Multiplies the base mana cost of the spell circle it is slotted into.
@export var mana_cost_multiplier := 1.5
@export var modifiers: Array[RuneModifier] = []


func get_card_type() -> CardType:
	return CardType.RUNE
