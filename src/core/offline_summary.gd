class_name OfflineSummary
extends RefCounted
## What happened during offline progress, returned by
## [method Simulation.progress_offline]. Changing it does not change the
## simulation.

## The time that offline progress advanced the simulation.
var duration_ms: int = 0
## Time away above [method Simulation.max_offline_ms], which gave no progress.
## The caller sets it from [method Simulation.offline_progress_ms].
var skipped_ms: int = 0
## The money from all sales, before the cost of shipments.
var money_earned: BigNumber = BigNumber.ZERO
## Widgets that markets bought.
var widgets_sold: int = 0
## Widgets that all factories made, including widgets that mixed factories
## consumed later.
var widgets_made: int = 0


## Adds [param other] to this summary, for offline progress in more than one
## part.
func add(other: OfflineSummary) -> void:
	duration_ms += other.duration_ms
	skipped_ms += other.skipped_ms
	money_earned = money_earned.add(other.money_earned)
	widgets_sold += other.widgets_sold
	widgets_made += other.widgets_made
