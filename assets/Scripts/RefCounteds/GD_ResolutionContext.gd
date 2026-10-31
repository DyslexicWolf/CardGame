class_name ResolutionContext
extends RefCounted

var enemy: Enemy
var row: Array[BaseCard] = [] # slot order, null = empty slot
var current_index := -1
var depth := 0
var total_damage := 0
var total_activations := 0
var aborted := false
# BaseCard -> times it was re-triggered this turn
var retrigger_counts: Dictionary = { }

# Callables set by CombatManager. They avoid a class_name cycle between the two scripts.
var activate_fn: Callable
var deal_damage_fn: Callable


func get_card_at(index: int) -> BaseCard:
	if index < 0 or index >= row.size():
		return null
	return row[index]


## Re-activates a card (damage counts as a new activation).
func retrigger(card: BaseCard, source: BaseCard) -> void:
	await activate_fn.call(card, source)


## For effects that deal extra damage (counts toward total_damage, not activations).
func deal_damage(amount: int, type: CardResource.DamageType, source: BaseCard) -> int:
	return deal_damage_fn.call(amount, type, source) as int
