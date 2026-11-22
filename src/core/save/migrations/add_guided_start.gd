extends SaveMigration
## #26 adds the guided start. A save from before it is from earlier play, and a
## new game with no earlier play is the only game that starts the guide. So an
## older game gets a guide that is done, and does not show it.


func needs() -> Array[StringName]:
	return [&"add_save_time"]


func apply(state: Dictionary) -> Dictionary:
	state.guided_start = "done"
	return state
