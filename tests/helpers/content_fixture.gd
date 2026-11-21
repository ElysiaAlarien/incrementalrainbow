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
## the base price.
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
	}
	var prism := {"first_price": FIRST_PRISM_PRICE, "price_growth": 2.0}
	for key: String in overrides:
		var section: Dictionary = {}
		for candidate: Dictionary in [run, factory, demand, prism]:
			if candidate.has(key):
				section = candidate
		assert(not section.is_empty(), "unknown balance key %s" % key)
		section[key] = overrides[key]
	return {"run": run, "factory": factory, "demand": demand, "prism": prism}


## Overrides for [method balance_data] that turn on drift (up to 30%, with a
## knot each 10 s) and saturation (10 recent widgets halve demand, and each
## widget takes 1 s to recover).
static func demand_overrides() -> Dictionary:
	return {"drift_amplitude": 0.3, "saturation_ms_per_widget": 1000}


## Markets, one for each of [param ids] (by default only "millbrook"), that
## each pay a base price of [param price] for each color in [param colors].
static func markets_data(price: float = PRICE, colors: Dictionary = colors_data(),
		ids: PackedStringArray = ["millbrook"]) -> Dictionary:
	var prices := {}
	for color: Dictionary in colors.colors:
		prices[color.id] = price
	var markets := []
	for id in ids:
		markets.append({"id": id, "name": id.capitalize(), "prices": prices})
	return {"markets": markets}


## One transport tier, carts, and automatic transport for [param automatic_cost].
static func transport_data(transit_time_ms: int = TRANSIT_TIME_MS,
		shipment_cost: float = SHIPMENT_COST, automatic_cost: float = AUTOMATIC_COST) -> Dictionary:
	return {"automatic_transport_cost": automatic_cost, "tiers": [
		{"id": "cart", "name": "Cart", "transit_time_ms": transit_time_ms, "shipment_cost": shipment_cost},
	]}


## Data for [method Content.from_data], with each section replaceable. When
## [param markets] is null, one market prices every color in [param colors].
static func data(colors: Dictionary = colors_data(), balance: Dictionary = balance_data(),
		markets: Variant = null, transport: Dictionary = transport_data()) -> Dictionary:
	if markets == null:
		markets = markets_data(PRICE, colors)
	return {"colors": colors, "balance": balance, "markets": markets, "transport": transport}


## Content with one widget per [param widget_time_ms] for each production line,
## an output bay of [param output_bay_capacity], 100 starting money, and a flat
## production line cost of 10.
static func make(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	return make_with_balance(balance_data(widget_time_ms, output_bay_capacity))


## Like [method make], with the colors of [method mixed_colors_data]. The save
## fixtures in tests/fixtures/saves/ load with this content.
static func make_mixed(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	return from_data(data(mixed_colors_data(), balance_data(widget_time_ms, output_bay_capacity)))


## Content with the test colors and [param balance] from [method balance_data].
static func make_with_balance(balance: Dictionary) -> Content:
	return from_data(data(colors_data(), balance))


## Content from [param p_data], which must be valid.
static func from_data(p_data: Dictionary) -> Content:
	var content := Content.from_data(p_data)
	assert(content.errors.is_empty(), "test content is valid: %s" % "; ".join(content.errors))
	return content
