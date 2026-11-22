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
## How hard the market is to reach. The market is open only when the
## player's transport tier reaches it (see [method TransportTier.reaches]).
var remoteness: int:
	get:
		return _remoteness

var _id: StringName
var _name: String
var _prices: Dictionary[StringName, BigNumber]
## The keys of [member _prices], in their order, and their values.
var _price_colors: Array[StringName] = []
var _price_values: Array[BigNumber] = []
var _start_population: int
var _start_income: int
var _remoteness: int


func _init(p_id: StringName, p_name: String, p_prices: Dictionary[StringName, BigNumber],
		p_start_population: int, p_start_income: int, p_remoteness: int) -> void:
	_id = p_id
	_name = p_name
	_prices = p_prices.duplicate()
	_price_colors.assign(_prices.keys())
	_price_values.assign(_prices.values())
	_start_population = p_start_population
	_start_income = p_start_income
	_remoteness = p_remoteness


## The base price of one widget of [param color], or null for a color that is
## not in the content.
func price(color: StringName) -> BigNumber:
	return _prices.get(color)


## The ids of the colors that [member prices] has, in its order. Returns a
## copy.
func price_colors() -> Array[StringName]:
	return _price_colors.duplicate()


## The base prices of [method price_colors], in the same order. Returns a
## copy.
func base_prices() -> Array[BigNumber]:
	return _price_values.duplicate()
