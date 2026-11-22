class_name MarketBalance
extends RefCounted
## Balance values for market capacity, prices from income, and community
## investment, from balance.json. Read-only. All values are placeholders until
## playtests set them.

## The length of one period. Capacity is the count of widgets that a market
## buys in one period. Periods start at time 0 and follow each other with no
## gap. The spec does not set this length yet (a gap in the design).
var period_ms: int:
	get:
		return _period_ms
## The capacity of a market is its population times this, rounded down.
var capacity_per_population: float:
	get:
		return _capacity_per_population
## The income at which a market pays the base price. Prices are in proportion
## to income: double this income pays double the base price.
var reference_income: float:
	get:
		return _reference_income
## The cost of the first community investment of each kind in a market.
var investment_cost: BigNumber:
	get:
		return _investment_cost
## Each community investment of one kind in one market costs this many times
## the one before it.
var investment_cost_growth: float:
	get:
		return _investment_cost_growth
## The population that one community investment for population adds.
var population_step: int:
	get:
		return _population_step
## The income that one community investment for income adds.
var income_step: int:
	get:
		return _income_step

var _period_ms: int
var _capacity_per_population: float
var _reference_income: float
var _investment_cost: BigNumber
var _investment_cost_growth: float
var _population_step: int
var _income_step: int
## The number of investments made, to the cost of the next one, so that a
## query of all markets does not compute them again. Not state: the costs
## follow from the values above.
var _investment_costs: Dictionary[int, BigNumber] = {}


func _init(p_period_ms: int, p_capacity_per_population: float, p_reference_income: float,
		p_investment_cost: BigNumber, p_investment_cost_growth: float,
		p_population_step: int, p_income_step: int) -> void:
	_period_ms = p_period_ms
	_capacity_per_population = p_capacity_per_population
	_reference_income = p_reference_income
	_investment_cost = p_investment_cost
	_investment_cost_growth = p_investment_cost_growth
	_population_step = p_population_step
	_income_step = p_income_step


## The capacity of a market with [param population]: a higher population gives
## a capacity that is at least as high. The content check that
## [code]population_step * capacity_per_population[/code] is at least 1 makes
## each community investment for population add capacity.
func capacity(population: int) -> int:
	return floori(population * _capacity_per_population)


## The factor that income gives to each base price: 1 at
## [member reference_income].
func income_factor(income: int) -> float:
	return income / _reference_income


## The cost of a community investment of one kind in a market that has had
## [param made] investments of that kind. Costs are whole numbers.
func investment_cost_after(made: int) -> BigNumber:
	var cost: BigNumber = _investment_costs.get(made)
	if cost == null:
		cost = _investment_cost.times_power(_investment_cost_growth, made).ceiled()
		_investment_costs[made] = cost
	return cost


## The number of the period that holds [param at_ms]: 0 for the first period.
func period(at_ms: int) -> int:
	@warning_ignore("integer_division")
	return at_ms / _period_ms


## The time when the period that holds [param at_ms] ends.
func period_end_ms(at_ms: int) -> int:
	return (period(at_ms) + 1) * _period_ms
