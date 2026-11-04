class_name ResolutionContext
extends RefCounted

var enemy: Enemy
var rows: Array[SpellRow] = [] # cast order (top to bottom), rows without a spell circle stay so indices are meaningful
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


## The spell circle card of the row at `index` (null if out of range or the row is empty).
func get_card_at(index: int) -> BaseCard:
	if index < 0 or index >= rows.size():
		return null
	return rows[index].get_circle_card()


func row_of(circle_card: BaseCard) -> SpellRow:
	for row in rows:
		if row.get_circle_card() == circle_card:
			return row
	return null


## Re-casts a spell circle's whole row (counts as new activations).
func retrigger(card: BaseCard, source: BaseCard) -> void:
	await activate_fn.call(card, source)


## For effects that deal extra damage (counts toward total_damage, not activations).
func deal_damage(amount: int, type: CardResource.DamageType, source: BaseCard) -> int:
	return deal_damage_fn.call(amount, type, source) as int
