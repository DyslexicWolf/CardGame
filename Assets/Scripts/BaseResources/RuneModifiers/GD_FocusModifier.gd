@tool
class_name FocusModifier
extends RuneModifier
## Trades projectiles for damage. Does nothing if the spell only has 1 projectile left.
@export var removed_projectiles := 1
@export var added_damage := 4


func modify(spell: ResolvedSpell) -> void:
	if spell.projectiles <= 1:
		return
	spell.projectiles = maxi(spell.projectiles - removed_projectiles, 1)
	spell.damage += added_damage
