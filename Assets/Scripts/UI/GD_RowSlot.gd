class_name RowSlot
extends PanelContainer

signal card_dropped(slot: RowSlot, card: BaseCard)

const LOCKED_MODULATE := Color(0.35, 0.35, 0.4, 0.6)

## Which kind of card this slot holds.
@export var accepted_type := CardResource.CardType.RUNE

var card: BaseCard = null
## Locked slots are past the spell circle's rune limit and can't take a card.
var locked := false:
	set(value):
		locked = value
		modulate = LOCKED_MODULATE if locked else Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is BaseCard


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(self, data as BaseCard)


func is_empty() -> bool:
	return card == null


func accepts(resource: CardResource) -> bool:
	return resource != null and resource.get_card_type() == accepted_type


func assign(new_card: BaseCard) -> void:
	card = new_card


func clear() -> void:
	card = null


func get_card_resource() -> CardResource:
	return card.card_resource if card else null
