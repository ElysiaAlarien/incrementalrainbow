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
## The name of more than one vehicle of the tier, such as "Trucks".
var plural_name: String:
	get:
		return _plural_name
## Time for one shipment to go from a link's source to its destination.
var transit_time_ms: int:
	get:
		return _transit_time_ms
## Money that one shipment costs when it starts.
var shipment_cost: BigNumber:
	get:
		return _shipment_cost
## The place of the tier in the list of tiers: 0 for the first tier, which a
## run starts with. A higher rank comes later.
var rank: int:
	get:
		return _rank
## The highest market remoteness that the tier reaches.
var max_remoteness: int:
	get:
		return _max_remoteness
## The money to buy the tier. Zero for the first tier.
var price: BigNumber:
	get:
		return _price
## The money to move the vehicle of one link onto this tier. Zero for the
## first tier.
var vehicle_upgrade_cost: BigNumber:
	get:
		return _vehicle_upgrade_cost

var _id: StringName
var _name: String
var _transit_time_ms: int
var _shipment_cost: BigNumber
var _rank: int
var _max_remoteness: int
var _price: BigNumber
var _vehicle_upgrade_cost: BigNumber
var _plural_name: String


func _init(p_id: StringName, p_name: String, p_transit_time_ms: int, p_shipment_cost: BigNumber,
		p_rank: int, p_max_remoteness: int, p_price: BigNumber, p_vehicle_upgrade_cost: BigNumber,
		p_plural_name: String) -> void:
	_id = p_id
	_name = p_name
	_transit_time_ms = p_transit_time_ms
	_shipment_cost = p_shipment_cost
	_rank = p_rank
	_max_remoteness = p_max_remoteness
	_price = p_price
	_vehicle_upgrade_cost = p_vehicle_upgrade_cost
	_plural_name = p_plural_name


## True if the tier reaches a market of [param remoteness].
func reaches(remoteness: int) -> bool:
	return remoteness <= _max_remoteness
