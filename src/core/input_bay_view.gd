class_name InputBayView
extends RefCounted
## A read-only copy of one input bay of a mixed factory, returned in
## [member FactoryView.input_bays]. Changing it does not change the simulation.

## The input color that the bay holds.
var color: StringName
## Widgets in the bay now.
var count: int
## Widgets the bay holds when it is full.
var capacity: int
## Widgets of this color that one widget of the factory consumes.
var per_widget: int
## Widgets of this color in shipments on their way to this bay. A shipment
## leaves only with what fits next to the bay count and these widgets.
var in_transit: int


## True if the bay holds too few widgets for one more widget of the factory.
func is_short() -> bool:
	return count < per_widget
