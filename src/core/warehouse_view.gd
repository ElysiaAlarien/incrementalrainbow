class_name WarehouseView
extends RefCounted
## A read-only copy of one warehouse, returned by simulation queries. Changing
## it does not change the simulation.

## The value of [member sell_threshold] when the warehouse has none.
const NO_SELL_THRESHOLD := -1

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
## The demand, as a whole percent of normal demand, below which the warehouse
## holds its color from a market, or [constant NO_SELL_THRESHOLD]. See
## [method Simulation.set_sell_threshold].
var sell_threshold: int = NO_SELL_THRESHOLD
## The markets that the warehouse holds its color from now: the markets at the
## end of its automatic links whose demand for its color is below
## [member sell_threshold], in link order. A manual link never holds.
var held_market_ids: Array[StringName] = []


## True when the warehouse holds its color from at least one market now.
func holds() -> bool:
	return not held_market_ids.is_empty()


## The space that is not full and not kept for widgets on their way.
func free_space() -> int:
	return space - count - in_transit
