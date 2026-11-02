@tool
class_name AddLightDamageModifier
extends SigilModifier
@export var added_damage := 2


func modify(spell: ResolvedSpell) -> void:
	if spell.damage_type == CardResource.DamageType.LIGHT:
		spell.damage += added_damage
