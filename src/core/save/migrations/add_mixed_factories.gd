extends SaveMigration
## Save version 6 (#6) adds mixed factories: each factory has input bays, and a
## link goes to a market or to a factory. A version 5 game had only base
## factories, which have no input bays, and only links to markets.


func needs() -> Array[StringName]:
	return [&"add_prisms"]


func apply(state: Dictionary) -> Dictionary:
	for key: String in ["factories", "links"]:
		var items: Variant = state.get(key)
		if not items is Array:
			continue
		for item: Variant in items:
			if not item is Dictionary:
				continue
			if key == "factories":
				item.input_bays = []
			else:
				item.destination_kind = "market"
	return state
