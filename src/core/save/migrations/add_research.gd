extends SaveMigration
## Save version 11 (#16) adds labs and research. A version 10 game had no labs
## and no research, so no link went to a lab.


func needs() -> Array[StringName]:
	return [&"add_transport_tier"]


func apply(state: Dictionary) -> Dictionary:
	state.next_lab_id = 1
	state.labs = []
	state.selected_research = ""
	state.research_progress = []
	state.completed_research = []
	state.lab_stock = []
	return state
