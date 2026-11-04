class_name ResolvedSpell
extends RefCounted

var damage := 0
var damage_type: CardResource.DamageType
var projectiles := 1
var damage_multiplier := 1.0
var recasts := 0 ## Extra times the finished spell fires
var rune_count := 0 ## Runes slotted in this spell's row
var pending_echoes := 0 ## Set by EchoModifier while a rune is applied


func get_hit_damage() -> int:
	return maxi(roundi(damage * damage_multiplier), 0)
