extends SaveMigration
## Save version 7 (#9) adds demand events. A version 6 game had none, and its
## next start is not set, so that this step does not draw from the random
## number generator. The first tick after the load sets it.


func needs() -> Array[StringName]:
	return [&"add_mixed_factories"]


func apply(state: Dictionary) -> Dictionary:
	state.demand_events = []
	state.next_demand_event_ms = -1
	return state
