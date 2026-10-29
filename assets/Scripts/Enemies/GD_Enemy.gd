class_name Enemy
extends Node

signal health_changed(current_hp: int, max_health: int)
signal damage_taken(amount: int, type: CardResource.DamageType)
signal died

@export var max_health := 100

var health: int


func _ready() -> void:
	health = max_health


func is_dead() -> bool:
	return health <= 0


## Returns the damage actually dealt after modifiers. Overkill still counts.
func take_damage(amount: int, type: CardResource.DamageType) -> int:
	if is_dead():
		return 0
	var final_amount := maxi(0, _modify_damage(amount, type))
	health = maxi(0, health - final_amount)
	damage_taken.emit(final_amount, type)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
	return final_amount


## Hook for resistances/weaknesses later.
func _modify_damage(amount: int, _type: CardResource.DamageType) -> int:
	return amount
