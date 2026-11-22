class_name PrestigeUpgradeView
extends RefCounted
## A read-only copy of one prestige upgrade and whether the player owns it,
## returned by simulation queries. Changing it does not change the simulation.

var id: StringName
var name: String
## The prisms that it costs.
var price: int
## True if the player bought it, in this run or an earlier one.
var owned: bool
## Factories make widgets this many times as fast. 1.0 for no bonus.
var production_speed: float = 1.0
## Money added at once and at the start of each later run. 0 for no bonus.
var starting_money: BigNumber = BigNumber.ZERO
## The colors that it unlocks.
var unlock_colors: Array[StringName] = []
