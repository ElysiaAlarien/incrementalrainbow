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
func advance(duration_ms: int, widget_time_ms: int, output_bay_capacity: int) -> void:
	var space := output_bay_capacity - output_bay_count
	if space <= 0:
		progress_ms = 0
		return
	progress_ms += duration_ms
	var made := progress_ms / widget_time_ms
	if made >= space:
		output_bay_count = output_bay_capacity
		progress_ms = 0
	else:
		output_bay_count += made
		progress_ms -= made * widget_time_ms


func is_output_bay_full(output_bay_capacity: int) -> bool:
	return output_bay_count >= output_bay_capacity


func to_dict() -> Dictionary:
	return {
		"id": id,
		"color": color,
		"output_bay_count": output_bay_count,
		"progress_ms": progress_ms,
	}
