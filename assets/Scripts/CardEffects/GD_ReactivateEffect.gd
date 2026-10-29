class_name ReactivateEffect
extends CardEffect

## 1-based slot to reactivate. If relative, it's an offset from the current slot (-1 = the slot above).
@export var target_slot := 1
@export var relative := false


func execute(ctx: ResolutionContext, source: BaseCard) -> void:
	var index := ctx.current_index + target_slot if relative else target_slot - 1
	var target := ctx.get_card_at(index)
	if target == null or target == source:
		return # empty slot or self-reactivate: nothing to do
	await ctx.retrigger(target, source)
