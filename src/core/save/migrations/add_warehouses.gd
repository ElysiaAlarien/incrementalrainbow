extends SaveMigration
## Save version 9 (#13) adds warehouses, and a link starts at a factory or at a
## warehouse. A version 8 game had no warehouses, so each link starts at a
## factory.


func needs() -> Array[StringName]:
	return [&"add_markets"]


func apply(state: Dictionary) -> Dictionary:
	state.next_warehouse_id = 1
	state.warehouses = []
	var links: Variant = state.get("links")
	if links is Array:
		for link: Variant in links:
			if link is Dictionary:
				link.source_kind = "factory"
	return state
