class_name RowSlot
extends PanelContainer

signal card_dropped(slot: RowSlot, card: BaseCard)

var card: BaseCard = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is BaseCard


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(self, data as BaseCard)


func is_empty() -> bool:
	return card == null


func assign(new_card: BaseCard) -> void:
	card = new_card


func clear() -> void:
	card = null


func get_card_resource() -> CardResource:
	return card.card_resource if card else null
