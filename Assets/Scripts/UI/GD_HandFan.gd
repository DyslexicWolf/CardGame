class_name HandFan
extends Control

## One hand of cards, laid out in a fan around this node's position.
## The cards are children of this node.

@export var max_cards := 8

@export_group("Fan")
##Radius of the arc
@export var fan_radius := 900.0
##Arc distance between adjacent cards
@export var card_spacing := 110.0
##Total spread limit
@export var max_fan_angle := deg_to_rad(40.0)
##Pushes the arc origin up/down
@export var fan_center_offset := 0.0

var cards: Array[BaseCard] = []


func get_room() -> int:
	return max_cards - cards.size()


## Returns [position, rotation] of the card at `index` in a fan of `total` cards.
func get_card_slot(index: int, total: int, card_size: Vector2) -> Array:
	var step := card_spacing / fan_radius
	if total > 1:
		step = minf(step, max_fan_angle / float(total - 1))
	var angle := (index - (total - 1) * 0.5) * step

	var origin := Vector2(size.x * 0.5, size.y + fan_radius + fan_center_offset)
	var pos := origin + Vector2(sin(angle), -cos(angle)) * fan_radius
	return [pos - card_size * 0.5, angle]
