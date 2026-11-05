class_name RuneCard
extends BaseCard

## The description is written in runes (SH_RuneText.gdshader) until the card is hovered.

@export var reveal_duration := 0.3

@export_group("Nodes")
@export var multiplier_label: Label
@export var description_label: Label
@export var rune_text_label: Label

var _reveal := 0.0
var _reveal_tween: Tween


func setup(resource: CardResource) -> void:
	super(resource)
	var rune := resource as RuneResource
	multiplier_label.text = String.num(rune.mana_cost_multiplier, 2)
	description_label.text = rune.description
	rune_text_label.text = rune.description
	_set_reveal(0.0)


func _on_hover_state_changed(hovered: bool) -> void:
	if not is_inside_tree():
		return
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(_set_reveal, _reveal, 1.0 if hovered else 0.0, reveal_duration)


func _set_reveal(value: float) -> void:
	_reveal = value
	(description_label.material as ShaderMaterial).set_shader_parameter("reveal", value)
	(rune_text_label.material as ShaderMaterial).set_shader_parameter("reveal", value)
