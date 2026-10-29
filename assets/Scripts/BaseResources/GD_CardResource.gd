@tool
class_name CardResource
extends Resource

@export var damage: int
@export var card_art_texture: Texture2D
@export var energy_cost: int


func _get_custom_preview_texture() -> Texture2D:
	return card_art_texture
