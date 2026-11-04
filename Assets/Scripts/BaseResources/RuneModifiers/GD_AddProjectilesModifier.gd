@tool
class_name AddProjectilesModifier
extends RuneModifier
@export var extra_projectiles := 1


func modify(spell: ResolvedSpell) -> void:
	spell.projectiles += extra_projectiles
