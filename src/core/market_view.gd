class_name MarketView
extends RefCounted
## A read-only copy of one market, returned by simulation queries. Changing it
## does not change the simulation.

## What a community investment grows.
enum Investment {
	## More population, which gives more capacity.
	POPULATION,
	## More income, which gives higher prices.
	INCOME,
}

var id: StringName
var name: String
## How many consumers the market has. Capacity comes from it.
var population: int
## How much the consumers can earn and spend. Prices come from it.
var income: int
## The total count of widgets, of all colors, that the market buys in one
## period.
var capacity: int
## The widgets that the market sold in the current period. It goes back to 0
## at the start of each period.
var capacity_used: int
## The widgets on their way to the market. They count against the capacity
## of the period in which a shipment leaves, so that the market never gets more
## widgets than its capacity.
var capacity_in_transit: int
## The widgets that a shipment that leaves now can carry to this market: the
## capacity less the widgets sold in this period and on their way. Never less
## than 0. When it is 0, shipments to the market do not start.
var capacity_left: int
## The time until the current period ends and capacity used goes back to 0.
var period_ends_in_ms: int
## The money that the next community investment for population costs.
var population_investment_cost: BigNumber
## The money that the next community investment for income costs.
var income_investment_cost: BigNumber
## Color id to the demand of that color now. 1 is normal demand. Drift moves it
## up and down, and the player's recent sales of the color here lower it.
var demands: Dictionary[StringName, float] = {}
## Color id to the money that one widget of that color sells for now: the base
## price times demand, times the factor from income.
var prices: Dictionary[StringName, BigNumber] = {}


## The demand of [param color] now, or NAN for an unknown color.
func demand(color: StringName) -> float:
	return demands.get(color, NAN)


## The price of one widget of [param color] now, or null for an unknown color.
func price(color: StringName) -> BigNumber:
	return prices.get(color)


## The money that the next community investment for [param goal] costs.
func investment_cost(goal: Investment) -> BigNumber:
	return population_investment_cost if goal == Investment.POPULATION else income_investment_cost
