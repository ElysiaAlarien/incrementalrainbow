class_name FactoryView
extends RefCounted
## A read-only copy of one factory, returned by simulation queries. Changing it
## does not change the simulation.

enum Status {
	## The factory makes widgets.
	RUNNING,
	## The output bay is full, so the factory has stopped. This status wins
	## when an input bay is short too.
	OUTPUT_BAY_FULL,
	## A mixed factory has too few widgets in an input bay for one full
	## recipe, so it waits. [method missing_inputs] tells which inputs.
	WAITING_FOR_INPUT,
}

var id: int
var color: StringName
## How many production lines the factory has.
var size: int
## The cost to add one more production line.
var next_line_cost: BigNumber
var output_bay_count: int
var output_bay_capacity: int
var status: Status
## One bay for each input color of the recipe, in recipe order. Empty for a
## base factory.
var input_bays: Array[InputBayView] = []


func is_stopped() -> bool:
	return status != Status.RUNNING


## The input colors whose bay holds too few widgets for one more widget, in
## recipe order.
func missing_inputs() -> Array[StringName]:
	var colors: Array[StringName] = []
	for bay in input_bays:
		if bay.is_short():
			colors.append(bay.color)
	return colors
