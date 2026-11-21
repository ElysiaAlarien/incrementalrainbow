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
## How many widgets each input bay of a mixed factory holds.
var input_bay_capacity: int:
	get:
		return _input_bay_capacity
## The cost of the second production line of a factory. A new factory has one line.
var production_line_cost: BigNumber:
	get:
		return _production_line_cost
## Each production line costs this many times the one before it. 1.0 gives a
## flat cost.
var production_line_cost_growth: float:
	get:
		return _production_line_cost_growth

## Money that building one factory costs.
var build_cost: BigNumber:
	get:
		return _build_cost

var _widget_time_ms: int
var _output_bay_capacity: int
var _input_bay_capacity: int
var _production_line_cost: BigNumber
var _production_line_cost_growth: float
var _build_cost: BigNumber


func _init(p_widget_time_ms: int, p_output_bay_capacity: int,
		p_production_line_cost: BigNumber, p_production_line_cost_growth: float,
		p_build_cost: BigNumber, p_input_bay_capacity: int) -> void:
	_widget_time_ms = p_widget_time_ms
	_output_bay_capacity = p_output_bay_capacity
	_production_line_cost = p_production_line_cost
	_production_line_cost_growth = p_production_line_cost_growth
	_build_cost = p_build_cost
	_input_bay_capacity = p_input_bay_capacity


## The cost to add one production line to a factory that has [param size]
## lines. Costs are whole numbers, so the money the screen shows is enough
## exactly when it is at least the cost the screen shows.
func next_line_cost(size: int) -> BigNumber:
	return _production_line_cost.times_power(_production_line_cost_growth, size - 1).ceiled()
