class_name CombatManager
extends Node

signal resolution_started
signal card_activation_started(card: BaseCard, is_retrigger: bool)
signal damage_dealt(amount: int, type: CardResource.DamageType, card: BaseCard)
signal totals_changed(total_damage: int, total_activations: int)
signal resolution_finished(enemy_died: bool)

@export var player_hand: PlayerHand
@export var enemy: Enemy
@export var combat_ui_state: CombatUIState

@export_group("Resolution")
@export var activation_delay := 0.35
@export var pop_duration := 0.12
@export var pop_scale := 1.3
@export var pop_lift := 30.0
@export_subgroup("Safety")
@export var max_activations := 50
@export var max_depth := 4
## If true, a re-triggered card also runs its own effect (bounded by max_depth).
@export var retriggers_run_effects := false

var _ctx: ResolutionContext
var _resolving := false


func _ready() -> void:
	PlayerUI.change_state("HUDState")
	combat_ui_state.end_turn_requested.connect(resolve_turn)
	resolution_started.connect(combat_ui_state.set_end_turn_enabled.bind(false))
	resolution_finished.connect(_on_resolution_finished)


func resolve_turn() -> void:
	if _resolving:
		return

	var row := player_hand.get_row_cards()
	if not row.any(
		func(c: BaseCard) -> bool:
			return c != null,
	):
		return # no cards in the row: nothing happens

	_resolving = true
	_ctx = ResolutionContext.new()
	_ctx.enemy = enemy
	_ctx.row = row
	_ctx.activate_fn = activate_card
	_ctx.deal_damage_fn = deal_damage

	BaseCard.set_interaction_locked(true)
	resolution_started.emit()
	totals_changed.emit(0, 0)

	for i in _ctx.row.size():
		if _ctx.aborted:
			break
		var card := _ctx.row[i]
		if card == null:
			continue
		_ctx.current_index = i
		await activate_card(card)

	await player_hand.discard_row_cards()

	BaseCard.set_interaction_locked(false)
	_resolving = false
	resolution_finished.emit(enemy.is_dead())


## One activation: pop -> damage -> pause -> effect -> settle.
## `source` is the card that triggered this one (null for the normal row pass).
func activate_card(card: BaseCard, source: BaseCard = null) -> void:
	if _ctx.aborted or not is_instance_valid(card) or card.card_resource == null:
		return
	if _ctx.total_activations >= max_activations:
		push_warning("Activation cap reached, stopping resolution.")
		_ctx.aborted = true
		return
	if _ctx.depth >= max_depth:
		return

	var is_retrigger := source != null
	if is_retrigger:
		# Per-card cap: a card can only be re-triggered max_retriggers times per turn.
		var used: int = _ctx.retrigger_counts.get(card, 0)
		if used >= card.card_resource.max_retriggers:
			return
		_ctx.retrigger_counts[card] = used + 1

	_ctx.depth += 1
	_ctx.total_activations += 1
	card_activation_started.emit(card, is_retrigger)
	totals_changed.emit(_ctx.total_damage, _ctx.total_activations)

	await _pop_card(card)
	deal_damage(card.card_resource.damage, card.card_resource.damage_type, card)
	await _wait(activation_delay)

	var effect := card.card_resource.effect
	if effect != null and not _ctx.aborted and (not is_retrigger or retriggers_run_effects):
		@warning_ignore("redundant_await")
		await effect.execute(_ctx, card)

	if is_instance_valid(card):
		card.go_home(pop_duration)
	_ctx.depth -= 1


## Immediate damage: enemy HP drops now, counters update, UI is notified.
func deal_damage(amount: int, type: CardResource.DamageType, source: BaseCard) -> int:
	var dealt := enemy.take_damage(amount, type)
	_ctx.total_damage += dealt
	damage_dealt.emit(dealt, type, source)
	totals_changed.emit(_ctx.total_damage, _ctx.total_activations)
	if enemy.is_dead():
		_ctx.aborted = true # stop the loop; finish signal reports the death
	return dealt


func _pop_card(card: BaseCard) -> void:
	card.z_index = BaseCard.HOVER_Z
	card.tween_visual(
		card.home_position + Vector2(0, -pop_lift),
		0.0,
		pop_scale,
		pop_duration,
		0.0,
		Tween.EASE_OUT,
		Tween.TRANS_BACK,
	)
	await _wait(pop_duration)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


func _on_resolution_finished(enemy_died: bool) -> void:
	combat_ui_state.set_end_turn_enabled(not enemy_died)
