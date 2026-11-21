class_name MarketDef
extends RefCounted
## One market from the content data. Read-only.

var id: StringName:
	get:
		return _id
var name: String:
	get:
		return _name
## Color id to the base price: the money that one widget of that color sells
## for at demand 1 and at [member MarketBalance.reference_income]. Every color has a base price. Returns a copy. The price now
## is in [MarketView].
var prices: Dictionary[StringName, BigNumber]:
	get:
		return _prices.duplicate()
## The population of the market at the start of a run. Community investment
## grows it. The population now is in [MarketView].
var start_population: int:
	get:
		return _start_population
## The income of the market at the start of a run. Community investment grows
## it. The income now is in [MarketView].
var start_income: int:
	get:
		return _start_income

var _id: StringName
var _name: String
var _prices: Dictionary[StringName, BigNumber]
var _start_population: int
var _start_income: int


func _init(p_id: StringName, p_name: String, p_prices: Dictionary[StringName, BigNumber],
		p_start_population: int, p_start_income: int) -> void:
	_id = p_id
	_name = p_name
	_prices = p_prices.duplicate()
	_start_population = p_start_population
	_start_income = p_start_income


## The base price of one widget of [param color], or null for a color that is
## not in the content.
func price(color: StringName) -> BigNumber:
	return _prices.get(color)
