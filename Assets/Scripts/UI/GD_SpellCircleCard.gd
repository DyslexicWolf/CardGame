class_name SpellCircleCard
extends BaseCard

@export_group("Backgrounds")
@export var fire_background: Texture2D
@export var electric_background: Texture2D
@export var light_background: Texture2D
@export var dark_background: Texture2D

@export_group("Nodes")
@export var background: TextureRect
@export var name_label: Label
@export var damage_label: Label
@export var projectiles_label: Label
@export var mana_label: Label
@export var runes_label: Label


func setup(resource: CardResource) -> void:
	super(resource)
	var circle := resource as SpellCircleResource
	background.texture = _background_for(circle.damage_type)
	name_label.text = circle.card_name
	damage_label.text = str(circle.damage)
	projectiles_label.text = str(circle.projectiles)
	mana_label.text = str(circle.base_mana_cost)
	runes_label.text = "Runes %d" % circle.max_runes


func _background_for(type: CardResource.DamageType) -> Texture2D:
	match type:
		CardResource.DamageType.ELECTRIC:
			return electric_background
		CardResource.DamageType.LIGHT:
			return light_background
		CardResource.DamageType.DARK:
			return dark_background
	return fire_background
