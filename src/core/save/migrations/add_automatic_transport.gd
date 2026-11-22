extends SaveMigration
## Save version 3 (#7) adds automatic transport and the recent starts that give
## throughput. A version 2 link was manual, and it has no starts to count.


func needs() -> Array[StringName]:
	return [&"add_links"]


func apply(state: Dictionary) -> Dictionary:
	var links: Variant = state.get("links")
	if links is Array:
		for link: Variant in links:
			if link is Dictionary:
				link.automatic_status = "manual"
				link.next_automatic_ms = 0
				link.recent_starts = []
	return state
