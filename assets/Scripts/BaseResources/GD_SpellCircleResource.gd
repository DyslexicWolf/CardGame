@tool
class_name SpellCircleResource
extends CardResource

@export var damage := 1 ## Damage per projectile
@export var damage_type: DamageType
@export var base_mana_cost := 1
## How many spell sigils can be attached to this spell circle.
@export var max_sigils := 2
## Can be left empty, then only damage will happen
@export var effect: CardEffect
## How many times this card can be re-triggered per turn by other cards' effects.
@export var max_retriggers := 1


func get_card_type() -> CardType:
	return CardType.SPELL_CIRCLE


## Base cost increased by every attached spell sigil's multiplier, added together.
## Each sigil adds (multiplier - 1) x base cost. Rounded up.
func get_mana_cost(sigils: Array[SpellSigilResource] = []) -> int:
	var total_mult := 1.0
	for sigil in sigils:
		total_mult += sigil.mana_cost_multiplier - 1.0
	return maxi(ceili(snappedf(base_mana_cost * total_mult, 0.001)), 0)


## Applies the sigils in order and returns the final spell to fire.
func build_spell(sigils: Array[SpellSigilResource] = []) -> ResolvedSpell:
	var spell := ResolvedSpell.new()
	spell.damage = damage
	spell.damage_type = damage_type
	for sigil in sigils:
		for modifier in sigil.modifiers:
			if modifier:
				modifier.modify(spell)
	spell.damage = maxi(spell.damage, 0)
	spell.projectiles = maxi(spell.projectiles, 1)
	return spell
