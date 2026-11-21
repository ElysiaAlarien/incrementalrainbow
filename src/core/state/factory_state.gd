extends RefCounted
## Internal to the core. The mutable state of one factory and its production
## rules. Code outside src/core reads factories through FactoryView.

var id: int
var color: StringName
var output_bay_count: int = 0
## Time worked on the next widget.
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
	progress_ms += duration_ms
	@warning_ignore("integer_division")
	var made := progress_ms / balance.widget_time_ms
	if made >= space:
		output_bay_count = balance.output_bay_capacity
		progress_ms = 0
	else:
		output_bay_count += made
		progress_ms -= made * balance.widget_time_ms


func to_view(balance: FactoryBalance) -> FactoryView:
	var view := FactoryView.new()
	view.id = id
	view.color = color
	view.output_bay_count = output_bay_count
	view.output_bay_capacity = balance.output_bay_capacity
	view.status = FactoryView.Status.OUTPUT_BAY_FULL \
		if output_bay_count >= balance.output_bay_capacity else FactoryView.Status.RUNNING
	return view


func to_dict() -> Dictionary:
	return {
		"id": id,
		"color": color,
		"output_bay_count": output_bay_count,
		"progress_ms": progress_ms,
	}
