class_name MarketView
extends RefCounted
## A read-only copy of one market, returned by simulation queries. Changing it
## does not change the simulation.

var id: StringName
var name: String
## Color id to the money that one widget of that color sells for now.
var prices: Dictionary[StringName, BigNumber] = {}


## The price of one widget of [param color] now, or null for an unknown color.
func price(color: StringName) -> BigNumber:
	return prices.get(color)
