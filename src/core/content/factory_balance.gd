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
## The cost of the second production line of a factory. A new factory has one line.
var production_line_cost: BigNumber:
	get:
		return _production_line_cost
## Each production line costs this many times the one before it. 1.0 gives a
## flat cost.
var production_line_cost_growth: float:
	get:
		return _production_line_cost_growth

var _widget_time_ms: int
var _output_bay_capacity: int
var _production_line_cost: BigNumber
var _production_line_cost_growth: float


func _init(p_widget_time_ms: int, p_output_bay_capacity: int,
		p_production_line_cost: BigNumber = BigNumber.ZERO,
		p_production_line_cost_growth: float = 1.0) -> void:
	_widget_time_ms = p_widget_time_ms
	_output_bay_capacity = p_output_bay_capacity
	_production_line_cost = p_production_line_cost
	_production_line_cost_growth = p_production_line_cost_growth


## The cost to add one production line to a factory that has [param size] lines.
func next_line_cost(size: int) -> BigNumber:
	return BigNumber.scaled_power(_production_line_cost, _production_line_cost_growth, size - 1)
