@tool
class_name MultipleProjectileModifier
extends SigilModifier
@export var extra_projectiles := 1


func modify(spell: ResolvedSpell) -> void:
	spell.projectiles += extra_projectiles
