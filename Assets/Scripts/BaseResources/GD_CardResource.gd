@tool
class_name CardResource
extends Resource

enum DamageType {
	FIRE,
	ELECTRIC,
	LIGHT,
	DARK,
}
enum CardType {
	SPELL_CIRCLE,
	SPELL_SIGIL,
}

@export var card_name := ""
@export var card_art_texture: Texture2D
@export_multiline var description := ""


func get_card_type() -> CardType:
	return CardType.SPELL_CIRCLE


func _get_custom_preview_texture() -> Texture2D:
	return card_art_texture
