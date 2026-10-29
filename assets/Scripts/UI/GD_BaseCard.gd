class_name BaseCard
extends PanelContainer

signal hover_started(card: BaseCard)
signal hover_ended(card: BaseCard)
signal drag_started(card: BaseCard)
signal drag_released(card: BaseCard, global_pos: Vector2)

const HOVER_Z := 100
const DRAG_Z := 200

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)
	set_process_input(false)


func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - size * 0.5


func _input(event: InputEvent) -> void:
	if (
		is_dragging and event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_end_drag()


func _gui_input(event: InputEvent) -> void:
	if (event.is_action_pressed("LeftFire") and not is_dragging):
		accept_event()
		_begin_drag()


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
	_hovered = false
	return tween_visual(home_position, home_rotation, 1.0, duration, delay)


func dispose() -> void:
	_kill_tween()
	queue_free()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_mouse_entered() -> void:
	if is_dragging:
		return
	_hovered = true
	z_index = HOVER_Z
	tween_visual(home_position + Vector2(0, -hover_lift), 0.0, hover_scale, hover_duration)
	hover_started.emit(self)


func _on_mouse_exited() -> void:
	if is_dragging or not _hovered:
		return
	_hovered = false
	go_home(hover_duration)
	hover_ended.emit(self)


func _begin_drag() -> void:
	is_dragging = true
	_kill_tween()
	z_index = DRAG_Z

	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "rotation", 0.0, 0.1)
	t.tween_property(self, "scale", Vector2.ONE * hover_scale, 0.1)
	_tween = t
	set_process(true)
	set_process_input(true)
	drag_started.emit(self)


func _end_drag() -> void:
	is_dragging = false
	set_process(false)
	set_process_input(false)
	drag_released.emit(self, get_global_mouse_position())


func _on_resized() -> void:
	pivot_offset = size * 0.5
