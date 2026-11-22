extends SaveMigration
## #12 adds the count of generated markets. An older game had none. The load
## then makes them as a new game would (see [method Simulation.from_snapshot]).


func needs() -> Array[StringName]:
	return [&"add_save_time"]


func apply(state: Dictionary) -> Dictionary:
	state.generated_markets = 0
	return state
