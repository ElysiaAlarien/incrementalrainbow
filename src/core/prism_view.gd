class_name PrismView
extends RefCounted
## A read-only copy of the player's prisms, returned by
## [method Simulation.prisms]. Changing it does not change the simulation.

## The prisms the player has now.
var owned: int
## All prisms bought across all runs. Prestige does not clear it, and the
## price of the next prism depends on it.
var total_bought: int
## The money that the next prism costs.
var next_price: BigNumber
