class_name MarketView
extends RefCounted
## A read-only copy of one market, returned by simulation queries. Changing it
## does not change the simulation.

var id: StringName
var name: String
## Color id to the demand of that color now. 1 is normal demand. Drift moves it
## up and down, and the player's recent sales of the color here lower it.
var demands: Dictionary[StringName, float] = {}
## Color id to the money that one widget of that color sells for now: the base
## price times demand.
var prices: Dictionary[StringName, BigNumber] = {}


## The demand of [param color] now, or NAN for an unknown color.
func demand(color: StringName) -> float:
	return demands.get(color, NAN)


## The price of one widget of [param color] now, or null for an unknown color.
func price(color: StringName) -> BigNumber:
	return prices.get(color)
