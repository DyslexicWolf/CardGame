@tool
class_name ChangeDamageTypeModifier
extends RuneModifier
@export var new_type: CardResource.DamageType


func modify(spell: ResolvedSpell) -> void:
	spell.damage_type = new_type
