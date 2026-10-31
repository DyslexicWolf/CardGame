@tool
class_name SpellSigilResource
extends CardResource

## Multiplies the mana cost of the spell circle it is attached to.
@export var mana_cost_multiplier := 1.5
@export var modifiers: Array[SigilModifier] = []


func get_card_type() -> CardType:
	return CardType.SPELL_SIGIL
