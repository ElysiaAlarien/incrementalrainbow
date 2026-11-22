class_name LinkView
extends RefCounted
## A read-only copy of one link, returned by simulation queries. Changing it
## does not change the simulation.

enum Automatic {
	## The player starts each shipment by hand.
	MANUAL,
	## The link has automatic transport, and its first automatic start is next.
	READY,
	## The last automatic start sent a shipment.
	SHIPPED,
	## The last automatic start sent nothing: the source had no widgets, or
	## the destination accepted none.
	NOTHING_TO_SHIP,
	## The last automatic start sent nothing, because the player had less
	## money than the shipment costs.
	NOT_ENOUGH_MONEY,
	## The last automatic start sent nothing, because the link goes from a
	## warehouse to a market whose demand was below the warehouse's sell
	## threshold.
	HELD,
}

## What kind of place a link goes to.
enum Destination {
	## A market, which sells the widgets.
	MARKET,
	## A mixed factory, which puts the widgets in the input bay of their color.
	FACTORY,
	## A warehouse, which holds the widgets.
	WAREHOUSE,
	## A lab, which consumes the widgets to pay for research.
	LAB,
}

## What kind of place a link takes widgets from.
enum Source {
	## The output bay of a factory.
	FACTORY,
	## A warehouse.
	WAREHOUSE,
}

## The value of [member split_percent] when the source has no split.
const NO_SPLIT := -1

var id: int
## The one color that the link carries.
var color: StringName
var source_kind: Source
## The factory at the start of the link, or 0 when it starts at a warehouse.
var source_factory_id: int
## The warehouse at the start of the link, or 0 when it starts at a factory.
var source_warehouse_id: int
var destination_kind: Destination
## The market at the end of the link, or &"" when it goes to another kind of
## place.
var destination_market_id: StringName
## The factory at the end of the link, or 0 when it goes to another kind of
## place.
var destination_factory_id: int
## The warehouse at the end of the link, or 0 when it goes to another kind of
## place.
var destination_warehouse_id: int
## The lab at the end of the link, or 0 when it goes to another kind of place.
var destination_lab_id: int
## The transport tier id of the link's vehicle, such as &"cart".
var vehicle: StringName
## Time for one shipment to arrive, from the vehicle.
var transit_time_ms: int
## Money that one shipment costs when it starts, from the vehicle.
var shipment_cost: BigNumber
## Shipments on their way, in the order they started.
var shipments_in_transit: Array[ShipmentView] = []
## Whether the link has automatic transport, and if so, what its last
## automatic start did.
var automatic: Automatic
## On an automatic link, the time until the next automatic start. 0 on a
## manual link.
var next_automatic_in_ms: int
## The throughput: widgets that started on the link, by hand or automatically,
## in the last minute.
var widgets_per_minute: int
## The percentage of the source's widgets that the split sends to this link,
## or [constant NO_SPLIT]. See [method Simulation.splits].
var split_percent: int = NO_SPLIT


func is_automatic() -> bool:
	return automatic != Automatic.MANUAL
