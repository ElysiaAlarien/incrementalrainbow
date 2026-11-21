extends RefCounted
## Internal to the core. The mutable state of one link and its shipments in
## transit. Code outside src/core reads links through LinkView.

const LinkState := preload("res://src/core/state/link_state.gd")
const ShipmentState := preload("res://src/core/state/shipment_state.gd")

var id: int
var color: StringName
var source_factory_id: int
var destination_market_id: StringName
## The transport tier id of the link's vehicle.
var vehicle: StringName
## Shipments in transit, in the order they started.
var shipments: Array[ShipmentState] = []


func _init(p_id: int, p_color: StringName, p_source_factory_id: int,
		p_destination_market_id: StringName, p_vehicle: StringName) -> void:
	id = p_id
	color = p_color
	source_factory_id = p_source_factory_id
	destination_market_id = p_destination_market_id
	vehicle = p_vehicle


## The inverse of [method to_dict]. Records problems in [param reader]. Checks
## the ids that the content must know; the simulation checks the source
## factory and the link id. [param now_ms], [param next_shipment_id], and
## [param shipment_ids] are for [method ShipmentState.from_snapshot].
static func from_snapshot(reader: SnapshotReader, content: Content, now_ms: int,
		next_shipment_id: int, shipment_ids: Dictionary) -> LinkState:
	var state := LinkState.new(reader.integer("id", 1), reader.text_id("color"),
		reader.integer("source_factory_id", 1), reader.text_id("destination_market_id"),
		reader.text_id("vehicle"))
	if state.color != &"" and content.color(state.color) == null:
		reader.fail("color", "there is no color \"%s\"" % state.color)
	if state.destination_market_id != &"" and content.market(state.destination_market_id) == null:
		reader.fail("destination_market_id", "there is no market \"%s\"" % state.destination_market_id)
	if state.vehicle != &"" and content.transport_tier(state.vehicle) == null:
		reader.fail("vehicle", "there is no transport tier \"%s\"" % state.vehicle)
	for shipment_reader in reader.objects("shipments"):
		state.shipments.append(ShipmentState.from_snapshot(shipment_reader, now_ms,
			next_shipment_id, shipment_ids))
	return state


func to_view(tier: TransportTier, now_ms: int) -> LinkView:
	var view := LinkView.new()
	view.id = id
	view.color = color
	view.source_factory_id = source_factory_id
	view.destination_market_id = destination_market_id
	view.vehicle = vehicle
	view.transit_time_ms = tier.transit_time_ms
	view.shipment_cost = tier.shipment_cost
	for shipment in shipments:
		view.shipments_in_transit.append(shipment.to_view(now_ms))
	return view


func to_dict() -> Dictionary:
	return {
		"id": id,
		"color": color,
		"source_factory_id": source_factory_id,
		"destination_market_id": destination_market_id,
		"vehicle": vehicle,
		"shipments": shipments.map(func(s: ShipmentState) -> Dictionary: return s.to_dict()),
	}
