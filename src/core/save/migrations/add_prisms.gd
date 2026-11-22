extends SaveMigration
## Save version 5 (#18) adds prisms. A version 4 game had bought none.


func needs() -> Array[StringName]:
	return [&"add_demand"]


func apply(state: Dictionary) -> Dictionary:
	state.prisms = 0
	state.prisms_bought = 0
	return state
