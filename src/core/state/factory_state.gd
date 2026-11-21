extends RefCounted
## Internal to the core. The mutable state of one factory and its production
## rules. Code outside src/core reads factories through FactoryView.

const FactoryState := preload("res://src/core/state/factory_state.gd")

var id: int
var color: StringName
## How many production lines the factory has. Each line makes one widget per
## [member FactoryBalance.widget_time_ms].
var size: int = 1
var output_bay_count: int = 0
## Work done on the next widgets, in line-milliseconds: one line working for
## one millisecond adds 1.
var progress_ms: int = 0


func _init(p_id: int, p_color: StringName) -> void:
	id = p_id
	color = p_color


## Makes widgets for [param duration_ms]. Constant time for any duration, and
## exact: one long advance gives the same state as many short ones.
## A factory with a full output bay has stopped, so it keeps no partial
## progress: it starts a new widget when the bay has space again.
func advance(duration_ms: int, balance: FactoryBalance) -> void:
	var space := balance.output_bay_capacity - output_bay_count
	if space <= 0:
		progress_ms = 0
		return
	# Compare durations, not work, so that a long tick on a large factory
	# cannot overflow.
	var work_to_fill := space * balance.widget_time_ms - progress_ms
	@warning_ignore("integer_division")
	var time_to_fill := (work_to_fill + size - 1) / size
	if duration_ms >= time_to_fill:
		output_bay_count = balance.output_bay_capacity
		progress_ms = 0
		return
	progress_ms += duration_ms * size
	@warning_ignore("integer_division")
	var made := progress_ms / balance.widget_time_ms
	output_bay_count += made
	progress_ms -= made * balance.widget_time_ms


## The inverse of [method to_dict]. Records problems in [param reader].
static func from_snapshot(reader: SnapshotReader, content: Content) -> FactoryState:
	var state := FactoryState.new(reader.integer("id", 1), reader.text_id("color"))
	var color_def := content.color(state.color)
	if state.color != &"" and color_def == null:
		reader.fail("color", "there is no color \"%s\"" % state.color)
	elif color_def != null and not color_def.is_base():
		reader.fail("color", "%s is not a base color" % color_def.name)
	state.size = reader.integer("size", 1)
	state.output_bay_count = reader.integer("output_bay_count")
	state.progress_ms = reader.integer("progress_ms")
	return state


func to_view(balance: FactoryBalance) -> FactoryView:
	var view := FactoryView.new()
	view.id = id
	view.color = color
	view.size = size
	view.next_line_cost = balance.next_line_cost(size)
	view.output_bay_count = output_bay_count
	view.output_bay_capacity = balance.output_bay_capacity
	view.status = FactoryView.Status.OUTPUT_BAY_FULL \
		if output_bay_count >= balance.output_bay_capacity else FactoryView.Status.RUNNING
	return view


func to_dict() -> Dictionary:
	return {
		"id": id,
		"color": color,
		"size": size,
		"output_bay_count": output_bay_count,
		"progress_ms": progress_ms,
	}
