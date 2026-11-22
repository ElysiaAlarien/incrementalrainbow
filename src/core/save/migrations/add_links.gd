extends SaveMigration
## Save version 2 (#3) adds links and their shipments. A version 1 game had
## none.


func apply(state: Dictionary) -> Dictionary:
	state.next_link_id = 1
	state.links = []
	state.next_shipment_id = 1
	return state
