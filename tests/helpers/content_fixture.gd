class_name ContentFixture
extends RefCounted
## Small content for tests, so tests do not depend on the game's data files.

const FACTORY_COST := 10
const PRICE := 5
const TRANSIT_TIME_MS := 5000
const SHIPMENT_COST := 2
const AUTOMATIC_COST := 20
const FIRST_PRISM_PRICE := 20
const INPUT_BAY_CAPACITY := 10
## The shortest and longest time between demand event starts in
## [method balance_data].
const EVENT_INTERVAL_MIN_MS := 5000
const EVENT_INTERVAL_MAX_MS := 10_000
## Each fixture market starts with this population and income. With the
## fixture balance, that gives a capacity of [constant CAPACITY] in each
## period of [constant PERIOD_MS], and prices at the base price.
const POPULATION := 1000
const INCOME := 100
const CAPACITY := 1000
const PERIOD_MS := 60_000
const INVESTMENT_COST := 10
const POPULATION_STEP := 100
const INCOME_STEP := 50
const WAREHOUSE_COST := 30
const WAREHOUSE_SPACE := 20


static func colors_data() -> Dictionary:
	return {"colors": [
		{"id": "red", "name": "Red", "symbol": "square", "display": "#d64545", "recipe": {}},
		{"id": "yellow", "name": "Yellow", "symbol": "triangle", "display": "#f2c230", "recipe": {}},
		{"id": "blue", "name": "Blue", "symbol": "circle", "display": "#3a6fd8", "recipe": {}},
	]}


## The three primary colors, plus green (1 yellow and 1 blue), purple (2 red
## and 1 blue, to test counts above 1), a tertiary color that research
## unlocks (blue-green: 1 blue and 1 green), and brown (red, yellow, and blue),
## which research unlocks too.
static func mixed_colors_data() -> Dictionary:
	var data := colors_data()
	data.colors.append_array([
		{"id": "green", "name": "Green", "symbol": "diamond", "display": "#3fa34d",
			"recipe": {"yellow": 1, "blue": 1}},
		{"id": "purple", "name": "Purple", "symbol": "hexagon", "display": "#8a4fc4",
			"recipe": {"red": 2, "blue": 1}},
		{"id": "blue_green", "name": "Blue-green", "symbol": "arrow", "display": "#2a9c94",
			"recipe": {"blue": 1, "green": 1}, "unlock": "research"},
		{"id": "brown", "name": "Brown", "symbol": "star", "display": "#8b5a33",
			"recipe": {"red": 1, "yellow": 1, "blue": 1}, "unlock": "research"},
	])
	return data


## Balance data: 100 starting money, factories that cost 10, input bays
## of 10, a flat
## production line cost of 10, prisms that cost 20, then 40, 80, and so on, and
## demand that stays at 1 (no drift and no saturation), so that prices stay at
## the base price. A demand event starts each 5 to 10 s, but [method data]
## has no demand events unless a test gives some. Markets: a capacity of 1 widget for each person, so the
## fixture markets have a capacity of [constant CAPACITY] in each period of
## [constant PERIOD_MS]; prices at the base price at [constant INCOME]; and
## community investments that cost 10, then 20, 40, and so on.
## Warehouses cost 30, hold 20, and are unlocked from the start.
## [param overrides] replaces values by key, such as
## [code]{"starting_money": 15, "production_line_cost_growth": 2.0}[/code].
## Keys are unique across the sections.
## [method demand_overrides] turns drift and saturation on.
static func balance_data(widget_time_ms: int = 1000, output_bay_capacity: int = 10,
		overrides: Dictionary = {}) -> Dictionary:
	var run := {"starting_money": 100}
	var factory := {
		"widget_time_ms": widget_time_ms,
		"output_bay_capacity": output_bay_capacity,
		"input_bay_capacity": INPUT_BAY_CAPACITY,
		"build_cost": FACTORY_COST,
		"production_line_cost": 10,
		"production_line_cost_growth": 1.0,
	}
	var demand := {
		"drift_period_ms": 10_000,
		"drift_amplitude": 0.0,
		"saturation_ms_per_widget": 0,
		"saturation_half_widgets": 10,
		"event_interval_min_ms": EVENT_INTERVAL_MIN_MS,
		"event_interval_max_ms": EVENT_INTERVAL_MAX_MS,
	}
	var prism := {"first_price": FIRST_PRISM_PRICE, "price_growth": 2.0}
	var market := {
		"period_ms": PERIOD_MS,
		"capacity_per_population": 1.0,
		"reference_income": INCOME,
		"investment_cost": INVESTMENT_COST,
		"investment_cost_growth": 2.0,
		"population_step": POPULATION_STEP,
		"income_step": INCOME_STEP,
	}
	var warehouse := {"cost": WAREHOUSE_COST, "space": WAREHOUSE_SPACE, "unlock_factory_count": 0}
	for key: String in overrides:
		var section: Dictionary = {}
		for candidate: Dictionary in [run, factory, demand, prism, market, warehouse]:
			if candidate.has(key):
				section = candidate
		assert(not section.is_empty(), "unknown balance key %s" % key)
		section[key] = overrides[key]
	return {"run": run, "factory": factory, "demand": demand, "prism": prism, "market": market, "warehouse": warehouse}


## Overrides for [method balance_data] that turn on drift (up to 30%, with a
## knot each 10 s) and saturation (10 recent widgets halve demand, and each
## widget takes 1 s to recover).
static func demand_overrides() -> Dictionary:
	return {"drift_amplitude": 0.3, "saturation_ms_per_widget": 1000}


## Markets, one for each of [param ids] (by default only "millbrook"), that
## each pay a base price of [param price] for each color in [param colors], and
## each start with [param population] and [param income].
static func markets_data(price: float = PRICE, colors: Dictionary = colors_data(),
		ids: PackedStringArray = ["millbrook"], population: int = POPULATION,
		income: int = INCOME) -> Dictionary:
	var prices := {}
	for color: Dictionary in colors.colors:
		prices[color.id] = price
	var markets := []
	for id in ids:
		markets.append({"id": id, "name": id.capitalize(), "population": population,
			"income": income, "prices": prices})
	return {"markets": markets}


## One transport tier, carts, and automatic transport for [param automatic_cost].
static func transport_data(transit_time_ms: int = TRANSIT_TIME_MS,
		shipment_cost: float = SHIPMENT_COST, automatic_cost: float = AUTOMATIC_COST) -> Dictionary:
	return {"automatic_transport_cost": automatic_cost, "tiers": [
		{"id": "cart", "name": "Cart", "transit_time_ms": transit_time_ms, "shipment_cost": shipment_cost},
	]}


## Demand events: a spike of red and blue by 0.5 for 20 s ("red_blue_spike"),
## and a crash of yellow by 0.4 for 30 s ("yellow_crash"). [param ids] picks
## which ones, in order.
static func demand_events_data(ids: PackedStringArray = ["red_blue_spike", "yellow_crash"]) -> Dictionary:
	var all := {
		"red_blue_spike": {"id": "red_blue_spike", "name": "Red and blue spike", "colors": ["red", "blue"],
			"direction": "spike", "size": 0.5, "duration_ms": 20_000},
		"yellow_crash": {"id": "yellow_crash", "name": "Yellow crash", "colors": ["yellow"],
			"direction": "crash", "size": 0.4, "duration_ms": 30_000},
	}
	var events := []
	for id in ids:
		events.append(all[id])
	return {"events": events}


## Data for [method Content.from_data], with each section replaceable. When
## [param markets] is null, one market prices every color in [param colors].
## By default there are no demand events.
static func data(colors: Dictionary = colors_data(), balance: Dictionary = balance_data(),
		markets: Variant = null, transport: Dictionary = transport_data(),
		demand_events: Dictionary = {"events": []}) -> Dictionary:
	if markets == null:
		markets = markets_data(PRICE, colors)
	return {"colors": colors, "balance": balance, "markets": markets, "transport": transport,
		"demand_events": demand_events}


## Content with one widget per [param widget_time_ms] for each production line,
## an output bay of [param output_bay_capacity], 100 starting money, and a flat
## production line cost of 10.
static func make(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	return make_with_balance(balance_data(widget_time_ms, output_bay_capacity))


## Like [method make], with the colors of [method mixed_colors_data].
static func make_mixed(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	return from_data(data(mixed_colors_data(), balance_data(widget_time_ms, output_bay_capacity)))


## The content that the save fixtures in tests/fixtures/saves/ load with: like
## [code]make_mixed(700, 6)[/code], with the demand events of
## [method demand_events_data].
static func make_for_saves() -> Content:
	return from_data(data(mixed_colors_data(), balance_data(700, 6), null, transport_data(),
		demand_events_data()))


## Content with the test colors and [param balance] from [method balance_data].
static func make_with_balance(balance: Dictionary) -> Content:
	return from_data(data(colors_data(), balance))


## Content from [param p_data], which must be valid.
static func from_data(p_data: Dictionary) -> Content:
	var content := Content.from_data(p_data)
	assert(content.errors.is_empty(), "test content is valid: %s" % "; ".join(content.errors))
	return content
