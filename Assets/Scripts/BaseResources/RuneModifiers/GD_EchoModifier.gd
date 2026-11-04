@tool
class_name EchoModifier
extends RuneModifier
## Extra times the other modifiers on the same rune are applied.
@export var echoes := 1


func modify(spell: ResolvedSpell) -> void:
	spell.pending_echoes += echoes
