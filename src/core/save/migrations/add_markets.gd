extends SaveMigration
## Save version 8 (#10) adds the state of each market: population, income,
## community investments, and capacity used in the current period. A migration
## gets no content, so it cannot know the markets. It writes none, and the load
## starts each market that a save does not have as at the start of a run. A
## version 7 game had made no community investments, so that is its state.
## Capacity used is 0, so the market can buy its full capacity in the period
## of the load.


func needs() -> Array[StringName]:
	return [&"add_demand_events"]


func apply(state: Dictionary) -> Dictionary:
	state.markets = []
	return state
