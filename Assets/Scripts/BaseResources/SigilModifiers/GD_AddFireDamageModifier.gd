@tool
class_name AddFireDamageModifier
extends SigilModifier
@export var added_damage := 2


func modify(spell: ResolvedSpell) -> void:
	if spell.damage_type == CardResource.DamageType.FIRE:
		spell.damage += added_damage
