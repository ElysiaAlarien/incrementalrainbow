class_name FactoryView
extends RefCounted
## A read-only copy of one factory, returned by simulation queries. Changing it
## does not change the simulation.

enum Status {
	## The factory makes widgets.
	RUNNING,
	## The output bay is full, so the factory has stopped.
	OUTPUT_BAY_FULL,
}

var id: int
var color: StringName
var output_bay_count: int
var output_bay_capacity: int
var status: Status


func is_stopped() -> bool:
	return status != Status.RUNNING
