@tool
class_name CardResource
extends Resource

enum DamageType {
	FIRE,
	ELECTRIC,
	LIGHT,
	DARK,
}

@export var damage: int
@export var card_art_texture: Texture2D
@export var energy_cost: int
@export var damage_type: DamageType
##Can be left empty, then only damage will happen
@export var effect: CardEffect
## How many times this card can be re-triggered per turn by other cards' effects.
@export var max_retriggers := 1


func _get_custom_preview_texture() -> Texture2D:
	return card_art_texture
