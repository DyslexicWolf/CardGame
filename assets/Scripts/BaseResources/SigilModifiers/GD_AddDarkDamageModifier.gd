@tool
class_name AddDarkDamageModifier
extends SigilModifier
@export var added_damage := 2


func modify(spell: ResolvedSpell) -> void:
	if spell.damage_type == CardResource.DamageType.DARK:
		spell.damage += added_damage
