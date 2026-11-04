class_name CombatManager
extends Node

signal resolution_started
signal card_activation_started(card: BaseCard, is_retrigger: bool)
signal spell_changed(spell: ResolvedSpell, circle_card: BaseCard)
signal damage_dealt(amount: int, type: CardResource.DamageType, card: BaseCard)
signal totals_changed(total_damage: int, total_activations: int)
signal resolution_finished(enemy_died: bool)

@export var player_hand: PlayerHand
@export var enemy: Enemy
@export var combat_ui_state: CombatUIState

@export var projectile_delay := 0.12
@export_group("Resolution")
@export var activation_delay := 0.35
@export var pop_duration := 0.12
@export var pop_scale := 1.3
@export var pop_lift := 30.0
@export_subgroup("Safety")
@export var max_activations := 50
@export var max_depth := 4
## If true, a re-cast spell also runs its spell circle's effect (bounded by max_depth).
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

	var rows := player_hand.get_spell_rows()
	if not rows.any(
		func(r: SpellRow) -> bool:
			return r.get_circle_card() != null,
	):
		return # no spell circles slotted: nothing happens

	_resolving = true
	_ctx = ResolutionContext.new()
	_ctx.enemy = enemy
	_ctx.rows = rows
	_ctx.activate_fn = cast_spell
	_ctx.deal_damage_fn = deal_damage

	BaseCard.set_interaction_locked(true)
	resolution_started.emit()
	totals_changed.emit(0, 0)

	for i in _ctx.rows.size():
		if _ctx.aborted:
			break
		var circle_card := _ctx.get_card_at(i)
		if circle_card == null:
			continue
		_ctx.current_index = i
		await cast_spell(circle_card)

	await player_hand.discard_row_cards()

	BaseCard.set_interaction_locked(false)
	_resolving = false
	resolution_finished.emit(enemy.is_dead())


## One spell: circle pops -> runes pop left to right and modify the spell -> spell fires -> circle effect.
## `source` is the card that re-cast this spell (null for the normal pass).
func cast_spell(circle_card: BaseCard, source: BaseCard = null) -> void:
	var circle := circle_card.card_resource as SpellCircleResource if is_instance_valid(circle_card) else null
	var row := _ctx.row_of(circle_card)
	if _ctx.aborted or circle == null or row == null:
		return
	if _ctx.depth >= max_depth:
		return

	var is_retrigger := source != null
	if is_retrigger:
		var used: int = _ctx.retrigger_counts.get(circle_card, 0)
		if used >= circle.max_retriggers:
			return
		_ctx.retrigger_counts[circle_card] = used + 1

	if not _count_activation(circle_card, is_retrigger):
		return
	_ctx.depth += 1

	await _pop_card(circle_card)
	var rune_cards := row.get_rune_cards()
	var spell := circle.create_spell(rune_cards.size())
	spell_changed.emit(spell, circle_card)

	for rune_card in rune_cards:
		if _ctx.aborted or not _count_activation(rune_card, is_retrigger):
			break
		await _pop_card(rune_card)
		SpellCircleResource.apply_rune(spell, rune_card.card_resource as RuneResource)
		spell_changed.emit(spell, circle_card)
		await _wait(activation_delay)
		if is_instance_valid(rune_card):
			rune_card.go_home(pop_duration)

	await _fire_spell(spell, circle_card)
	await _wait(activation_delay)

	var effect := circle.effect
	if effect != null and not _ctx.aborted and (not is_retrigger or retriggers_run_effects):
		@warning_ignore("redundant_await")
		await effect.execute(_ctx, circle_card)

	if is_instance_valid(circle_card):
		circle_card.go_home(pop_duration)
	_ctx.depth -= 1


## Every recast fires all projectiles again.
func _fire_spell(spell: ResolvedSpell, circle_card: BaseCard) -> void:
	var hits := (1 + spell.recasts) * spell.projectiles
	for h in hits:
		if _ctx.aborted:
			break
		deal_damage(spell.get_hit_damage(), spell.damage_type, circle_card)
		if h < hits - 1:
			await _wait(projectile_delay)


## Returns false (and stops the resolution) once the activation cap is reached.
func _count_activation(card: BaseCard, is_retrigger: bool) -> bool:
	if _ctx.total_activations >= max_activations:
		push_warning("Activation cap reached, stopping resolution.")
		_ctx.aborted = true
		return false
	_ctx.total_activations += 1
	card_activation_started.emit(card, is_retrigger)
	totals_changed.emit(_ctx.total_damage, _ctx.total_activations)
	return true


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
	card.tween_visual(card.home_position + Vector2(0, -pop_lift), 0.0, card.home_scale * pop_scale, pop_duration, 0.0, Tween.EASE_OUT, Tween.TRANS_BACK)
	await _wait(pop_duration)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


func _on_resolution_finished(enemy_died: bool) -> void:
	combat_ui_state.set_end_turn_enabled(not enemy_died)
