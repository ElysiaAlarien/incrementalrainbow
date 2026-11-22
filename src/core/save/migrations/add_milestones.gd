extends SaveMigration
## #25 adds milestones, for platform achievements. An older game had none.
##
## The load raises each milestone that the rest of the state shows, such as the
## first factory of each color (see [method Simulation._read_milestones]). The
## first sale is not in the state in that way, so this migration finds it from
## its traces: a market has capacity used, or a color has saturation. Both go
## away with time, so a sale from long ago can leave no trace. Then the player
## gets the first sale at the next sale. A prism is not a trace, because the
## starting money can buy one.
##
## The count of prestiges is not in an older state at all, so it starts at 0.


func needs() -> Array[StringName]:
	return [&"add_save_time"]


func apply(state: Dictionary) -> Dictionary:
	var milestones: Array = []
	if _has_sold(state):
		milestones.append({"id": "first_sale", "value": 1})
	state.milestones = milestones
	return state


static func _has_sold(state: Dictionary) -> bool:
	var saturation: Variant = state.get("saturation")
	if saturation is Array and not saturation.is_empty():
		return true
	var markets: Variant = state.get("markets")
	if markets is Array:
		for market: Variant in markets:
			if market is Dictionary:
				var used: Variant = market.get("capacity_used")
				if (used is int or used is float) and used > 0:
					return true
	return false
