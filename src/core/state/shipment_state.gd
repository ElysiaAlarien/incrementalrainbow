extends RefCounted
## Internal to the core. One shipment in transit on a link. Code outside
## src/core reads shipments through ShipmentView.

const ShipmentState := preload("res://src/core/state/shipment_state.gd")

## Unique across all links. Sets the sale order of shipments that arrive at
## the same time.
var id: int
var count: int
var arrives_at_ms: int


func _init(p_id: int, p_count: int, p_arrives_at_ms: int) -> void:
	id = p_id
	count = p_count
	arrives_at_ms = p_arrives_at_ms


## True if this shipment sells before [param other].
func arrives_before(other: Object) -> bool:
	if arrives_at_ms != other.arrives_at_ms:
		return arrives_at_ms < other.arrives_at_ms
	return id < other.id


## The inverse of [method to_dict]. Records problems in [param reader]. The id
## must be below [param next_id] and not in [param used_ids], which this adds
## it to. The shipment must arrive after [param now_ms], because a shipment
## that has arrived has sold.
static func from_snapshot(reader: SnapshotReader, now_ms: int, next_id: int,
		used_ids: Dictionary) -> ShipmentState:
	var state := ShipmentState.new(reader.integer("id", 1), reader.integer("count", 1),
		reader.integer("arrives_at_ms"))
	if used_ids.has(state.id):
		reader.fail("id", "is used by more than one shipment")
	elif state.id >= next_id:
		reader.fail("id", "must be less than next_shipment_id (%d)" % next_id)
	used_ids[state.id] = true
	if state.arrives_at_ms <= now_ms:
		reader.fail("arrives_at_ms", "must be after time_ms (%d), because an arrived shipment has sold" % now_ms)
	return state


func to_view(now_ms: int) -> ShipmentView:
	var view := ShipmentView.new()
	view.count = count
	view.remaining_ms = arrives_at_ms - now_ms
	return view


func to_dict() -> Dictionary:
	return {"id": id, "count": count, "arrives_at_ms": arrives_at_ms}
