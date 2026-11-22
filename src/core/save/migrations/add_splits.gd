extends SaveMigration
## Save version 12 (#14) adds splits: each link has a split percentage and the
## widgets it shipped since the split was set. A version 11 game had no splits.


func needs() -> Array[StringName]:
	return [&"add_research"]


func apply(state: Dictionary) -> Dictionary:
	var links: Variant = state.get("links")
	if links is Array:
		for link: Variant in links:
			if link is Dictionary:
				link.split_percent = -1
				link.split_shipped = 0
	return state
