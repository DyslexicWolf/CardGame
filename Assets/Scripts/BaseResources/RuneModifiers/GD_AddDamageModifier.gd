@tool
class_name AddDamageModifier
extends RuneModifier
@export var added_damage := 2
## If true, the damage is only added when the spell's type so far matches required_type.
@export var only_if_type := false
@export var required_type: CardResource.DamageType


func modify(spell: ResolvedSpell) -> void:
	if not only_if_type or spell.damage_type == required_type:
		spell.damage += added_damage
