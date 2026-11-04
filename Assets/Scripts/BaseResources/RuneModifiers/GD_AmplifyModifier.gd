@tool
class_name AmplifyModifier
extends RuneModifier
@export var multiplier := 1.5


func modify(spell: ResolvedSpell) -> void:
	spell.damage_multiplier *= multiplier
