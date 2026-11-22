extends SaveMigration
## #20 adds prestige upgrades. An older game had none.


func needs() -> Array[StringName]:
	return [&"add_save_time"]


func apply(state: Dictionary) -> Dictionary:
	state.prestige_upgrades = []
	return state
