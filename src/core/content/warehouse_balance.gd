class_name WarehouseBalance
extends RefCounted
## Balance values for warehouses, from balance.json. Read-only. All values are
## placeholders until playtests set them.

## Money that building one warehouse costs.
var build_cost: BigNumber:
	get:
		return _build_cost
## How many widgets a warehouse holds.
var space: int:
	get:
		return _space
## The player can build warehouses when they have at least this many
## factories in the run. 0 unlocks them at the start of each run.
var unlock_factory_count: int:
	get:
		return _unlock_factory_count

var _build_cost: BigNumber
var _space: int
var _unlock_factory_count: int


func _init(p_build_cost: BigNumber, p_space: int, p_unlock_factory_count: int) -> void:
	_build_cost = p_build_cost
	_space = p_space
	_unlock_factory_count = p_unlock_factory_count
