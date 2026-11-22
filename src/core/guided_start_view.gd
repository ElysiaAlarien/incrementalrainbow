class_name GuidedStartView
extends RefCounted
## A read-only copy of the guided start, returned by
## [method Simulation.guided_start]. Changing it does not change the
## simulation.
##
## The guided start teaches a new game to build a factory, make a link to a
## market, start a shipment on it, and sell at the market. Each step moves on
## when the core sees its action, not when the player presses a button, so it
## does not depend on the layout of the screen.

## The step that the player is at, in order. A later action also completes
## the steps before it. [constant DONE] and [constant SKIPPED] end the guide.
enum Step {
	## Build a factory of any color.
	BUILD_FACTORY,
	## Make a link from a factory or a warehouse to a market.
	MAKE_LINK,
	## Start a shipment on a link to a market, by hand or by automatic
	## transport.
	START_SHIPMENT,
	## Wait for a shipment to arrive at a market and sell there.
	SELL,
	## The player did each step.
	DONE,
	## The player skipped the guide, or ended its run with a prestige before
	## the end.
	SKIPPED,
}

var step: Step


## True while the guide shows a step to the player.
func is_active() -> bool:
	return step < Step.DONE
