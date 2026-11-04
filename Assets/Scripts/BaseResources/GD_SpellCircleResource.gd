@tool
class_name SpellCircleResource
extends CardResource

@export var damage := 1 ## Base damage per projectile
@export var damage_type: DamageType
@export var projectiles := 1 ## Base projectiles fired per cast
@export var base_mana_cost := 1
## How many runes can be slotted after this spell circle (capped by the row's rune slots).
@export var max_runes := 2
## Runs after the spell fires. Can be left empty, then only damage will happen.
@export var effect: CardEffect
## How many times this spell can be re-cast per turn by other cards' effects.
@export var max_retriggers := 1


func get_card_type() -> CardType:
	return CardType.SPELL_CIRCLE


## Base cost increased by every slotted rune's multiplier, added together.
## Each rune adds (multiplier - 1) x base cost. Rounded up.
func get_mana_cost(runes: Array[RuneResource] = []) -> int:
	var total_mult := 1.0
	for rune in runes:
		total_mult += rune.mana_cost_multiplier - 1.0
	return maxi(ceili(snappedf(base_mana_cost * total_mult, 0.001)), 0)


func create_spell(rune_count := 0) -> ResolvedSpell:
	var spell := ResolvedSpell.new()
	spell.damage = damage
	spell.damage_type = damage_type
	spell.projectiles = projectiles
	spell.rune_count = rune_count
	return spell


## Applies the runes in order and returns the final spell to fire.
func build_spell(runes: Array[RuneResource] = []) -> ResolvedSpell:
	var spell := create_spell(runes.size())
	for rune in runes:
		apply_rune(spell, rune)
	return spell


## Runs a rune's modifiers on the spell, then repeats the non-echo ones once per echo they queued.
static func apply_rune(spell: ResolvedSpell, rune: RuneResource) -> void:
	if rune == null:
		return
	spell.pending_echoes = 0
	for modifier in rune.modifiers:
		if modifier:
			modifier.modify(spell)
	var echoes := spell.pending_echoes
	spell.pending_echoes = 0
	for i in echoes:
		for modifier in rune.modifiers:
			if modifier and not modifier is EchoModifier:
				modifier.modify(spell)
	spell.damage = maxi(spell.damage, 0)
	spell.projectiles = maxi(spell.projectiles, 1)
