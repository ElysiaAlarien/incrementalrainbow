class_name WarehouseView
extends RefCounted
## A read-only copy of one warehouse, returned by simulation queries. Changing
## it does not change the simulation.

var id: int
## The one color that the warehouse holds.
var color: StringName
## Widgets in the warehouse now.
var count: int
## Widgets the warehouse holds when it is full.
var space: int
## Widgets in shipments on their way to the warehouse. A shipment leaves only
## with what fits next to the count and these widgets.
var in_transit: int
## The inflow throughput: widgets that started on the links to the warehouse
## in the last minute.
var inflow_per_minute: int
## The outflow throughput: widgets that started on the links from the
## warehouse in the last minute.
var outflow_per_minute: int


## The space that is not full and not kept for widgets on their way.
func free_space() -> int:
	return space - count - in_transit
