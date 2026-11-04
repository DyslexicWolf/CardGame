@tool
class_name RecastModifier
extends RuneModifier
## Extra times the finished spell fires all its projectiles.
@export var extra_casts := 1


func modify(spell: ResolvedSpell) -> void:
	spell.recasts += extra_casts
