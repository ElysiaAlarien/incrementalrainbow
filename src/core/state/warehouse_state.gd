extends RefCounted
## Internal to the core. The mutable state of one warehouse. Code outside
## src/core reads warehouses through WarehouseView.

const WarehouseState := preload("res://src/core/state/warehouse_state.gd")

var id: int
var color: StringName
## Widgets in the warehouse now.
var count: int = 0


func _init(p_id: int, p_color: StringName) -> void:
	id = p_id
	color = p_color


## Puts [param p_count] widgets into the warehouse. A shipment leaves only with
## what fits, so the warehouse never overflows.
func deliver(p_count: int, space: int) -> void:
	assert(count + p_count <= space, "warehouse #%d overflow" % id)
	count += p_count


## Removes [param p_count] widgets, for a shipment.
func take(p_count: int) -> void:
	assert(p_count >= 0 and p_count <= count, "cannot take %d of %d widgets" % [p_count, count])
	count -= p_count


## The inverse of [method to_dict]. Records problems in [param reader].
static func from_snapshot(reader: SnapshotReader, content: Content) -> WarehouseState:
	var state := WarehouseState.new(reader.integer("id", 1), reader.text_id("color"))
	if state.color != &"" and content.color(state.color) == null:
		reader.fail("color", "there is no color \"%s\"" % state.color)
	state.count = reader.integer("count", 0, content.warehouse_balance.space)
	return state


func to_view(space: int) -> WarehouseView:
	var view := WarehouseView.new()
	view.id = id
	view.color = color
	view.count = count
	view.space = space
	return view


func to_dict() -> Dictionary:
	return {"id": id, "color": color, "count": count}
