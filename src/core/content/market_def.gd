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
## for at demand 1. Every color has a base price. Returns a copy. The price now
## is in [MarketView].
var prices: Dictionary[StringName, BigNumber]:
	get:
		return _prices.duplicate()

var _id: StringName
var _name: String
var _prices: Dictionary[StringName, BigNumber]


func _init(p_id: StringName, p_name: String, p_prices: Dictionary[StringName, BigNumber]) -> void:
	_id = p_id
	_name = p_name
	_prices = p_prices.duplicate()


## The base price of one widget of [param color], or null for a color that is
## not in the content.
func price(color: StringName) -> BigNumber:
	return _prices.get(color)
