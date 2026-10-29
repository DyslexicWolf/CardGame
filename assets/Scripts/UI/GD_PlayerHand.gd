class_name PlayerHand
extends Control

signal card_played(card: BaseCard, global_pos: Vector2) # hook for future mechanics

@export var max_hand_size := 8
@export var draw_amount := 5
@export var card_scene: PackedScene
@export var draw_button: Button

@export_group("Fan")
##Radius of the arc
@export var fan_radius := 900.0
##Arc distance between adjacent cards
@export var card_spacing := 110.0
##Total spread limit
@export var max_fan_angle := deg_to_rad(40.0)
##Pushes the arc origin up/down
@export var fan_center_offset := 0.0

@export_group("Draw animation")
@export var draw_duration := 0.22
@export var draw_stagger := 0.08
@export var relayout_duration := 0.2

var _hand_cards: Array[BaseCard] = []
var _deck: Array[CardResource] = []
var _player_hand: Control


func _ready() -> void:
	_player_hand = self
	rebuild_deck()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)


func draw_cards(count: int) -> void:
	var amount := mini(count, mini(max_hand_size - _hand_cards.size(), _deck.size()))
	if amount <= 0:
		return

	var new_cards: Array[BaseCard] = []
	for i in amount:
		var card := _spawn_card(_deck.pop_back())
		_hand_cards.append(card)
		new_cards.append(card)

	_layout(new_cards)


func remove_card(card: BaseCard) -> void:
	_hand_cards.erase(card)
	card.dispose()
	_layout()


func clear_hand() -> void:
	for card in _hand_cards:
		card.dispose()
	_hand_cards.clear()


func rebuild_deck() -> void:
	_deck.clear()
	for c in Inventory.deck_cards:
		if c != null:
			_deck.append(c)
	_deck.shuffle()


func _on_draw_pressed() -> void:
	draw_cards(draw_amount)


func _spawn_card(resource: CardResource) -> BaseCard:
	var card: BaseCard = card_scene.instantiate()
	add_child(card)
	card.setup(resource)
	card.drag_released.connect(_on_card_drag_released)
	# Start above the hand, small and tilted.
	card.apply_visual(_spawn_position(card), 0.0, Vector2.ONE * 0.5)
	return card


func _spawn_position(card: BaseCard) -> Vector2:
	return Vector2(size.x * 0.5, -size.y) - card.size * 0.5


func _fan_slot(index: int, total: int, card_size: Vector2) -> Array:
	var step := card_spacing / fan_radius
	if total > 1:
		step = minf(step, max_fan_angle / float(total - 1))
	var angle := (index - (total - 1) * 0.5) * step

	var origin := Vector2(size.x * 0.5, size.y + fan_radius + fan_center_offset)
	var pos := origin + Vector2(sin(angle), -cos(angle)) * fan_radius
	return [pos - card_size * 0.5, angle]


func _layout(new_cards: Array[BaseCard] = []) -> void:
	var total := _hand_cards.size()
	var new_index := 0
	for i in total:
		var card := _hand_cards[i]
		if card.is_dragging:
			continue
		var slot := _fan_slot(i, total, card.size)
		card.home_position = slot[0]
		card.home_rotation = slot[1]
		card.home_z = i

		if card in new_cards:
			card.go_home(draw_duration, new_index * draw_stagger)
			new_index += 1
		else:
			card.go_home(relayout_duration)


func _on_card_drag_released(card: BaseCard, global_pos: Vector2) -> void:
	card_played.emit(card, global_pos)
	if card in _hand_cards:
		_layout()
