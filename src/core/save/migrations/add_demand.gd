extends SaveMigration
## Save version 4 (#8) adds demand: the drift key and saturation. A version 3
## game had no sales that saturate. Its drift key is a fixed 0, not a draw from
## its random number generator, so that this migration does not change the generator
## state. Any key gives valid drift.


func needs() -> Array[StringName]:
	return [&"add_automatic_transport"]


func apply(state: Dictionary) -> Dictionary:
	state.drift_key = 0
	state.saturation = []
	return state
