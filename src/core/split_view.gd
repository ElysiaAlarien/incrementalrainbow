class_name SplitView
extends RefCounted
## A read-only copy of the split of one color at one source, returned by
## [method Simulation.splits]. Changing it does not change the simulation.
##
## The split sends a percentage of the source's widgets of that color to each
## of its links. A link that the player left out of the split gets 0%.

## What kind of place the links start at.
var source_kind: LinkView.Source
## The factory that the links start at, or 0 when they start at a warehouse.
var source_factory_id: int
## The warehouse that the links start at, or 0 when they start at a factory.
var source_warehouse_id: int
## The color that the split shares.
var color: StringName
## The percentage for each link from the source, by link id, in link order.
## The percentages add up to 100.
var shares: Dictionary[int, int] = {}
## The widgets that each link shipped since the player set the split, by link
## id, in link order.
var shipped: Dictionary[int, int] = {}
