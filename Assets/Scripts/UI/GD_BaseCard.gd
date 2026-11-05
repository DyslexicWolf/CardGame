class_name BaseCard
extends Control

signal hover_started(card: BaseCard)
signal hover_ended(card: BaseCard)
signal drag_started(card: BaseCard)
signal drag_released(card: BaseCard, global_pos: Vector2)

const HOVER_Z := 100
const SLOT_Z := 150
const SLOTTED_HOVER_Z := 160
const DRAG_Z := 200

static var hovered_card: BaseCard = null
static var dragging_card: BaseCard = null
static var interaction_locked := false
static var _arbitrated_frame := -1

@export var art_texture: TextureRect

@export_group("Hover")
@export var hover_scale := 1.15
@export var hover_lift := 40.0
@export var hover_duration := 0.2
## Scale while being dragged.
@export var drag_scale := 1.15
## Hovered cards are kept this far inside the screen edges.
@export var hover_screen_margin := 8.0

var card_resource: CardResource
var home_position := Vector2.ZERO
var home_rotation := 0.0
var home_z := 0
var home_scale := 1.0
var is_dragging := false
var is_slotted := false
var is_flying := false
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
	return tween_visual(home_position, home_rotation, home_scale, duration, delay)


## Like go_home, but the card can't be hovered until it arrives.
func fly_home(duration: float, delay := 0.0) -> Tween:
	var t := go_home(duration, delay)
	is_flying = true
	t.finished.connect(
		func() -> void:
			is_flying = false,
	)
	return t


func snap_home() -> void:
	_kill_tween()
	_release_hover_ownership()
	z_index = home_z
	apply_visual(home_position, home_rotation, Vector2.ONE * home_scale)


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
	is_flying = false


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
	var best := _topmost_card_under_mouse()

	# Sticky hover, unless a slotted card is under the mouse (those take priority).
	if current and current._contains_mouse() and not (best and best.is_slotted):
		return

	if best == current:
		return
	if current:
		current._end_hover()
	if best:
		best._start_hover()


func _start_hover() -> void:
	if is_flying or is_dragging:
		return
	_hovered = true
	hovered_card = self
	if not is_slotted:
		z_index = HOVER_Z
	else:
		z_index = SLOTTED_HOVER_Z
	var lift := 0.0 if is_slotted else hover_lift
	tween_visual(_hover_position(lift), 0.0, hover_scale, hover_duration)
	_on_hover_state_changed(true)
	hover_started.emit(self)


func _end_hover() -> void:
	if not _hovered:
		return
	go_home(hover_duration)
	hover_ended.emit(self)


func _topmost_card_under_mouse() -> BaseCard:
	var best: BaseCard = null
	for node in get_tree().get_nodes_in_group("Cards"):
		var card := node as BaseCard
		if card == null or card.is_dragging or card.is_flying or not card.is_visible_in_tree() or not card._contains_mouse():
			continue
		if best == null \
				or card.z_index > best.z_index \
				or (card.z_index == best.z_index and card.get_index() > best.get_index()):
			best = card
	return best


## True if the mouse is inside this card's visual rect (scale/rotation/lift included).
## Slotted cards use the rect of their slot, so an enlarged one doesn't block its neighbours.
func _contains_mouse() -> bool:
	if is_slotted:
		return _slotted_rect().has_point(_parent_transform().affine_inverse() * get_global_mouse_position())
	var local := get_global_transform().affine_inverse() * get_global_mouse_position()
	return Rect2(Vector2.ZERO, size).has_point(local)


func _slotted_rect() -> Rect2:
	var scaled_size := size * home_scale
	return Rect2(home_position + (size - scaled_size) * 0.5, scaled_size)


func _parent_transform() -> Transform2D:
	var parent := get_parent() as CanvasItem
	return parent.get_global_transform() if parent else Transform2D.IDENTITY


## Where this card sits while hovered: lifted, but always fully on screen at hover_scale.
func _hover_position(lift: float) -> Vector2:
	var parent := _parent_transform()
	var center := parent * (home_position + size * 0.5 - Vector2(0, lift))
	var half := size * hover_scale * 0.5 + Vector2.ONE * hover_screen_margin
	var screen := get_viewport_rect().size
	center.x = clampf(center.x, half.x, maxf(half.x, screen.x - half.x))
	center.y = clampf(center.y, half.y, maxf(half.y, screen.y - half.y))
	return parent.affine_inverse() * center - size * 0.5


## Override to react to the card being hovered or not (also called when a drag takes over).
func _on_hover_state_changed(_hovered_now: bool) -> void:
	pass


func _release_hover_ownership() -> void:
	if _hovered:
		_on_hover_state_changed(false)
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
	t.tween_property(self, "scale", Vector2.ONE * drag_scale, 0.1)
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
