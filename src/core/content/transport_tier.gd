class_name TransportTier
extends RefCounted
## One transport tier from the content data, such as carts. A link's vehicle is
## a transport tier. Read-only.

var id: StringName:
	get:
		return _id
var name: String:
	get:
		return _name
## Time for one shipment to go from a link's source to its destination.
var transit_time_ms: int:
	get:
		return _transit_time_ms
## Money that one shipment costs when it starts.
var shipment_cost: BigNumber:
	get:
		return _shipment_cost

var _id: StringName
var _name: String
var _transit_time_ms: int
var _shipment_cost: BigNumber


func _init(p_id: StringName, p_name: String, p_transit_time_ms: int, p_shipment_cost: BigNumber) -> void:
	_id = p_id
	_name = p_name
	_transit_time_ms = p_transit_time_ms
	_shipment_cost = p_shipment_cost
