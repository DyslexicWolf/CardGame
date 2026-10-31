@tool
class_name AddElectricDamageModifier
extends SigilModifier
@export var added_damage := 2


func modify(spell: ResolvedSpell) -> void:
	if spell.damage_type == CardResource.DamageType.ELECTRIC:
		spell.damage += added_damage
