class_name PrestigeUpgradeDef
extends RefCounted
## One prestige upgrade from the content data: its price in prisms, its
## bonuses, and what it unlocks. Read-only.
##
## An upgrade has its effect from when the player buys it, and in all later
## runs. Each bonus kind has its own field, with a value that changes nothing
## when the upgrade does not give that bonus.

## The kinds of bonus that prestige_upgrades.json can give, as keys of
## "bonuses". Each kind that a later ticket adds goes here and gets its own
## field, and the simulation applies it.
const BONUS_KINDS: PackedStringArray = ["production_speed", "starting_money"]
## The kinds of unlock that prestige_upgrades.json can give, as keys of
## "unlocks". They have the same form as the unlocks of research.
const UNLOCK_KINDS: PackedStringArray = ["colors"]

var id: StringName:
	get:
		return _id
var name: String:
	get:
		return _name
## The prisms that the upgrade costs.
var price: int:
	get:
		return _price
## Factories make widgets this many times as fast. 1.0 when the upgrade does
## not give this bonus.
var production_speed: float:
	get:
		return _production_speed
## Money added to the start of each run, and to the money of the run in which
## the player buys the upgrade. 0 when the upgrade does not give this bonus.
var starting_money: BigNumber:
	get:
		return _starting_money
## The colors, and with them their recipes, that this upgrade unlocks.
## Returns a copy.
var unlock_colors: Array[StringName]:
	get:
		return _unlock_colors.duplicate()

var _id: StringName
var _name: String
var _price: int
var _production_speed: float
var _starting_money: BigNumber
var _unlock_colors: Array[StringName]


func _init(p_id: StringName, p_name: String, p_price: int, p_production_speed: float,
		p_starting_money: BigNumber, p_unlock_colors: Array[StringName]) -> void:
	_id = p_id
	_name = p_name
	_price = p_price
	_production_speed = p_production_speed
	_starting_money = p_starting_money
	_unlock_colors = p_unlock_colors.duplicate()


## True if this upgrade unlocks [param color].
func unlocks_color(color: StringName) -> bool:
	return _unlock_colors.has(color)
