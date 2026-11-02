class_name InventoryUIState
extends State

@export var card_scene: PackedScene
@export var deck_view: InventoryDeckView
@export var inventory_box_container: HBoxContainer
@export var starting_loadout: StartingLoadout

var inventory_ui_state: InventoryUIState
var _boxes: Array[InventoryBox] = []


func _ready() -> void:
	set_process_unhandled_input(false)
	inventory_ui_state = self
	deck_view.card_scene = card_scene
	deck_view.card_drag_released.connect(_on_deck_card_released)

	for child in inventory_box_container.get_children():
		if child is InventoryBox:
			var box := child as InventoryBox
			box.box_index = _boxes.size()
			box.card_scene = card_scene
			box.card_drag_released.connect(_on_box_card_released)
			_boxes.append(box)
	if _boxes.size() != Inventory.inventory_cards.size():
		push_warning(
			"InventoryUI: %d boxes but %d inventory slots."
			% [_boxes.size(), Inventory.inventory_cards.size()]
		)

	Inventory.cards_changed.connect(refresh, CONNECT_DEFERRED)
	if starting_loadout:
		Inventory.apply_loadout(starting_loadout)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not can_change_state:
		return

	if event.is_action_pressed("CloseUI") or event.is_action_pressed("Inventory"):
		get_viewport().set_input_as_handled()
		transitioned.emit(self, "HUDState")


func refresh() -> void:
	deck_view.show_cards(Inventory.deck_cards)
	for box in _boxes:
		box.set_card(
			(
				Inventory.inventory_cards[box.box_index]
				if box.box_index < Inventory.inventory_cards.size()
				else null
			)
		)


func _enter() -> void:
	get_tree().paused = false
	inventory_ui_state.show()
	refresh()
	set_process_unhandled_input(true)
	call_deferred("input_delay")


func _exit() -> void:
	set_process_unhandled_input(false)
	can_change_state = false
	inventory_ui_state.hide()
	refresh()


func _box_at(global_pos: Vector2) -> InventoryBox:
	for box in _boxes:
		if box.get_global_rect().has_point(global_pos):
			return box
	return null


func _on_deck_card_released(card: BaseCard, global_pos: Vector2, deck_index: int) -> void:
	var box := _box_at(global_pos)
	if (
		box
		and Inventory.move_card(
			Inventory.Zone.DECK,
			deck_index,
			Inventory.Zone.INVENTORY,
			box.box_index,
		)
	):
		return
	deck_view.return_card(card)


func _on_box_card_released(_card: BaseCard, global_pos: Vector2, box: InventoryBox) -> void:
	if deck_view.get_global_rect().has_point(global_pos):
		if Inventory.move_card(Inventory.Zone.INVENTORY, box.box_index, Inventory.Zone.DECK):
			return
	else:
		var target := _box_at(global_pos)
		if target and target != box \
				and Inventory.move_card(
			Inventory.Zone.INVENTORY,
			box.box_index,
			Inventory.Zone.INVENTORY,
			target.box_index,
		):
			return
	box.return_card()
