class_name ResearchView
extends RefCounted
## A read-only copy of one research and its progress, returned by simulation
## queries. Changing it does not change the simulation.

enum Status {
	## Research that it requires is not complete, so the player cannot select it.
	LOCKED,
	## The player can select it.
	AVAILABLE,
	## Labs pay for it now.
	SELECTED,
	## It is complete, and its unlocks are available.
	COMPLETE,
}

var id: StringName
var name: String
var status: Status
## Color id to the widgets that labs consume to complete it, in data order.
var cost: Dictionary[StringName, int] = {}
## Color id to the widgets paid, for each color of [member cost].
var paid: Dictionary[StringName, int] = {}
## Color id to the widgets on their way to labs, for each color of
## [member cost]. Only the selected research has them.
var in_transit: Dictionary[StringName, int] = {}
## The research that must be complete first.
var requires: Array[StringName] = []
## The colors that it unlocks.
var unlock_colors: Array[StringName] = []


## Paid widgets of all colors, from 0 to [method total_cost].
func total_paid() -> int:
	var total := 0
	for color in paid:
		total += paid[color]
	return total


## Widgets of all colors that the research costs.
func total_cost() -> int:
	var total := 0
	for color in cost:
		total += cost[color]
	return total
