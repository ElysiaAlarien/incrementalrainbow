class_name DemandEventView
extends RefCounted
## A read-only copy of one active demand event, returned by
## [method Simulation.demand_events]. An event changes the demand of its colors
## in every market. Changing this copy does not change the simulation.

## The id of the event in the content data.
var id: StringName
var name: String
## The colors whose demand changes, in data order.
var colors: Array[StringName] = []
var direction: DemandEventDef.Direction
## How much demand changes, as a fraction of demand (see [member DemandEventDef.size]).
var size: float
## The number that the event multiplies the demand of its colors by.
var factor: float
## The time when the event started.
var started_at_ms: int
## Time until the event ends and its effect stops.
var remaining_ms: int


func is_spike() -> bool:
	return direction == DemandEventDef.Direction.SPIKE
