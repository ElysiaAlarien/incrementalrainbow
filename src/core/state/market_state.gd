extends RefCounted
## Internal to the core. The mutable state of one market: its population, its
## income, the community investments made in it, and the widgets it sold in the
## current period. Code outside src/core reads markets through MarketView.
##
## Capacity is the count of widgets that a market buys in one period. The
## widgets sold in a period count against it. So do the widgets on their way to
## the market, which the simulation counts (see
## [method Simulation._accepted_count]). Periods are fixed by time (see
## [method MarketBalance.period]), so a period change is not an event: the
## count of sold widgets belongs to the period of the last sale, and a read at
## a time in a later period sees 0.

const MarketState := preload("res://src/core/state/market_state.gd")

var id: StringName
var population: int
var income: int
## The community investments for population made in this market, which set the
## cost of the next one.
var population_investments: int = 0
## The community investments for income made in this market.
var income_investments: int = 0
## Widgets sold in the period [member _period].
var _sold: int = 0
## The period of [member _sold].
var _period: int = 0


func _init(p_id: StringName, p_population: int, p_income: int) -> void:
	id = p_id
	population = p_population
	income = p_income


## A market as it is at the start of a run.
static func from_def(def: MarketDef) -> MarketState:
	return MarketState.new(def.id, def.start_population, def.start_income)


func capacity(balance: MarketBalance) -> int:
	return balance.capacity(population)


## The widgets that the market sold in the period that holds [param at_ms]. 0
## at the start of each period.
func capacity_used(at_ms: int, balance: MarketBalance) -> int:
	return _sold if balance.period(at_ms) == _period else 0


## Records a sale of [param count] widgets at [param at_ms]. Sales come in time
## order.
func record_sale(count: int, at_ms: int, balance: MarketBalance) -> void:
	_sold = capacity_used(at_ms, balance) + count
	_period = balance.period(at_ms)


## Forgets the sales of periods before the one that holds [param now_ms], so
## that the state does not depend on how time was cut into ticks.
func forget_old_periods(now_ms: int, balance: MarketBalance) -> void:
	_sold = capacity_used(now_ms, balance)
	_period = balance.period(now_ms)


## The community investments of one kind made in this market.
func investments(goal: MarketView.Investment) -> int:
	return population_investments if goal == MarketView.Investment.POPULATION else income_investments


## Makes one community investment for [param goal].
func invest(goal: MarketView.Investment, balance: MarketBalance) -> void:
	if goal == MarketView.Investment.POPULATION:
		population += balance.population_step
		population_investments += 1
	else:
		income += balance.income_step
		income_investments += 1


## The state as plain data. The sold count is for the period of the
## snapshot's time, after [method forget_old_periods].
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"population": population,
		"income": income,
		"population_investments": population_investments,
		"income_investments": income_investments,
		"capacity_used": _sold,
	}


## The inverse of [method to_dict]. Records problems in [param reader]. The
## simulation checks that the id is a known market, once. [param now_ms] is the
## time of the snapshot.
static func from_snapshot(reader: SnapshotReader, now_ms: int, balance: MarketBalance) -> MarketState:
	var state := MarketState.new(reader.text_id("id"), reader.integer("population", 1),
		reader.integer("income", 1))
	state.population_investments = reader.integer("population_investments", 0)
	state.income_investments = reader.integer("income_investments", 0)
	state._sold = reader.integer("capacity_used", 0)
	state._period = balance.period(now_ms)
	if state._sold > state.capacity(balance):
		reader.fail("capacity_used", "is more than the capacity (%d)" % state.capacity(balance))
	return state
