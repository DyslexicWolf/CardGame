class_name BaseCard
extends PanelContainer

signal hover_started(card: BaseCard)
signal hover_ended(card: BaseCard)
signal drag_started(card: BaseCard)
signal drag_released(card: BaseCard, global_pos: Vector2)

const HOVER_Z := 100
const DRAG_Z := 200

static var hovered_card: BaseCard = null
static var dragging_card: BaseCard = null
static var interaction_locked := false
static var _arbitrated_frame := -1

@export var art_texture: TextureRect
@export var effect_icon: TextureRect

@export_group("Hover")
@export var hover_scale := 1.15
@export var hover_lift := 40.0
@export var hover_duration := 0.2

var card_resource: CardResource
var home_position := Vector2.ZERO
var home_rotation := 0.0
var home_z := 0
var is_dragging := false
var _tween: Tween
var _hovered := false


static func set_interaction_locked(locked: bool) -> void:
	interaction_locked = locked
	if locked and is_instance_valid(hovered_card):
		hovered_card._end_hover()


func _ready() -> void:
	add_to_group("Cards")
	pivot_offset = size * 0.5
	resized.connect(_on_resized)


func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - size * 0.5
		return
	_arbitrate_hover()


func _input(event: InputEvent) -> void:
	if is_dragging or interaction_locked:
		return

	if _hovered and event.is_action_pressed("LeftFire") and _contains_mouse():
		get_viewport().set_input_as_handled()
		_begin_drag()


func _notification(what: int) -> void:
	# Sent to every control when any drag ends (dropped or cancelled).
	if what == NOTIFICATION_DRAG_END and is_dragging:
		_end_drag()


func setup(resource: CardResource) -> void:
	card_resource = resource
	if art_texture:
		art_texture.texture = resource.card_art_texture


func apply_visual(pos: Vector2, rot: float, scl: Vector2) -> void:
	position = pos
	rotation = rot
	scale = scl


func tween_visual(
	pos: Vector2,
	rot: float,
	scl: float,
	duration: float,
	delay := 0.0,
	ease_type := Tween.EASE_IN_OUT,
	trans := Tween.TRANS_CUBIC,
) -> Tween:
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(ease_type).set_trans(trans)
	_tween.tween_property(self, "position", pos, duration).set_delay(delay)
	_tween.tween_property(self, "rotation", rot, duration).set_delay(delay)
	_tween.tween_property(self, "scale", Vector2(scl, scl), duration).set_delay(delay)
	return _tween


func go_home(duration: float, delay := 0.0) -> Tween:
	z_index = home_z
	_release_hover_ownership()
	return tween_visual(home_position, home_rotation, 1.0, duration, delay)


func snap_home() -> void:
	_kill_tween()
	_release_hover_ownership()
	z_index = home_z
	apply_visual(home_position, home_rotation, Vector2.ONE)


func dispose() -> void:
	_kill_tween()
	_release_hover_ownership()
	if dragging_card == self:
		dragging_card = null
	queue_free()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


## Runs once per frame (whichever card processes first does the work).
## The current hovered card keeps the hover until the mouse is fully off its
## visual rect. Only then is the topmost card under the mouse chosen.
func _arbitrate_hover() -> void:
	var frame := Engine.get_process_frames()
	if frame == _arbitrated_frame:
		return
	_arbitrated_frame = frame

	if interaction_locked:
		return

	if is_instance_valid(dragging_card):
		return

	var current: BaseCard = hovered_card if is_instance_valid(hovered_card) else null
	if current and current._contains_mouse():
		return

	var best := _topmost_card_under_mouse()
	if best == current:
		return
	if current:
		current._end_hover()
	if best:
		best._start_hover()


func _topmost_card_under_mouse() -> BaseCard:
	var best: BaseCard = null
	for node in get_tree().get_nodes_in_group("Cards"):
		var card := node as BaseCard
		if card == null or card.is_dragging or not card._contains_mouse():
			continue
		if best == null \
				or card.z_index > best.z_index \
				or (card.z_index == best.z_index and card.get_index() > best.get_index()):
			best = card
	return best


## True if the mouse is inside this card's visual rect (scale/rotation/lift included).
func _contains_mouse() -> bool:
	var local := get_global_transform().affine_inverse() * get_global_mouse_position()
	return Rect2(Vector2.ZERO, size).has_point(local)


func _start_hover() -> void:
	_hovered = true
	hovered_card = self
	z_index = HOVER_Z
	tween_visual(home_position + Vector2(0, -hover_lift), 0.0, hover_scale, hover_duration)
	hover_started.emit(self)


func _end_hover() -> void:
	if not _hovered:
		return
	go_home(hover_duration)
	hover_ended.emit(self)


func _release_hover_ownership() -> void:
	_hovered = false
	if hovered_card == self:
		hovered_card = null


func _begin_drag() -> void:
	is_dragging = true
	dragging_card = self
	_release_hover_ownership()
	_kill_tween()
	z_index = DRAG_Z

	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "rotation", 0.0, 0.1)
	t.tween_property(self, "scale", Vector2.ONE * hover_scale, 0.1)
	_tween = t

	force_drag(self, Control.new())
	drag_started.emit(self)


func _end_drag() -> void:
	is_dragging = false
	if dragging_card == self:
		dragging_card = null
	drag_released.emit(self, get_global_mouse_position())


func _on_resized() -> void:
	pivot_offset = size * 0.5
