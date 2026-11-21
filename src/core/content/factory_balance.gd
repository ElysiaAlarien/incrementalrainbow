class_name FactoryBalance
extends RefCounted
## Balance values for factories, from balance.json. Read-only. All values are
## placeholders until playtests set them.

## Time for one production line to make one widget.
var widget_time_ms: int:
	get:
		return _widget_time_ms
## How many widgets an output bay holds.
var output_bay_capacity: int:
	get:
		return _output_bay_capacity

var _widget_time_ms: int
var _output_bay_capacity: int


func _init(p_widget_time_ms: int, p_output_bay_capacity: int) -> void:
	_widget_time_ms = p_widget_time_ms
	_output_bay_capacity = p_output_bay_capacity
