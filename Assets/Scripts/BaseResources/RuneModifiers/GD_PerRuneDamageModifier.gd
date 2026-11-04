@tool
class_name PerRuneDamageModifier
extends RuneModifier
## Damage added for every rune slotted in this spell's row (this one included).
@export var damage_per_rune := 1


func modify(spell: ResolvedSpell) -> void:
	spell.damage += damage_per_rune * spell.rune_count
