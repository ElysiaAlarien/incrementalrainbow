class_name LinkView
extends RefCounted
## A read-only copy of one link, returned by simulation queries. Changing it
## does not change the simulation.

var id: int
## The one color that the link carries.
var color: StringName
var source_factory_id: int
var destination_market_id: StringName
## The transport tier id of the link's vehicle, such as &"cart".
var vehicle: StringName
## Time for one shipment to arrive, from the vehicle.
var transit_time_ms: int
## Money that one shipment costs when it starts, from the vehicle.
var shipment_cost: BigNumber
## Shipments on their way, in the order they started.
var shipments_in_transit: Array[ShipmentView] = []
