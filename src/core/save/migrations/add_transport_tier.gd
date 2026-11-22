extends SaveMigration
## Save version 10 (#11) adds the transport tier that the player has. A version
## 9 game had only carts, the first tier, so its tier is "cart". The id is
## fixed here, because a step gets no content; carts were the only tier in the
## content of version 9, and every version 9 link uses them.


func needs() -> Array[StringName]:
	return [&"add_warehouses"]


func apply(state: Dictionary) -> Dictionary:
	state.transport_tier = "cart"
	return state
