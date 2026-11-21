class_name ContentFixture
extends RefCounted
## Small content for tests, so tests do not depend on the game's data files.

const FACTORY_COST := 10
const PRICE := 5
const TRANSIT_TIME_MS := 5000
const SHIPMENT_COST := 2


static func colors_data() -> Dictionary:
	return {"colors": [
		{"id": "red", "name": "Red", "symbol": "square", "display": "#d64545", "recipe": {}},
		{"id": "yellow", "name": "Yellow", "symbol": "triangle", "display": "#f2c230", "recipe": {}},
		{"id": "blue", "name": "Blue", "symbol": "circle", "display": "#3a6fd8", "recipe": {}},
	]}


## Balance data: 100 starting money, factories that cost 10, and a flat
## production line cost of 10.
## [param overrides] replaces values by key, such as
## [code]{"starting_money": 15, "production_line_cost_growth": 2.0}[/code].
static func balance_data(widget_time_ms: int = 1000, output_bay_capacity: int = 10,
		overrides: Dictionary = {}) -> Dictionary:
	var run := {"starting_money": 100}
	var factory := {
		"widget_time_ms": widget_time_ms,
		"output_bay_capacity": output_bay_capacity,
		"build_cost": FACTORY_COST,
		"production_line_cost": 10,
		"production_line_cost_growth": 1.0,
	}
	for key: String in overrides:
		var section := run if run.has(key) else factory
		assert(section.has(key), "unknown balance key %s" % key)
		section[key] = overrides[key]
	return {"run": run, "factory": factory}


## One market, "millbrook", that pays [param price] for each color in
## [param colors].
static func markets_data(price: float = PRICE, colors: Dictionary = colors_data()) -> Dictionary:
	var prices := {}
	for color: Dictionary in colors.colors:
		prices[color.id] = price
	return {"markets": [{"id": "millbrook", "name": "Millbrook", "prices": prices}]}


## One transport tier, carts.
static func transport_data(transit_time_ms: int = TRANSIT_TIME_MS,
		shipment_cost: float = SHIPMENT_COST) -> Dictionary:
	return {"tiers": [
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


## Content with the test colors and [param balance] from [method balance_data].
static func make_with_balance(balance: Dictionary) -> Content:
	return from_data(data(colors_data(), balance))


## Content from [param p_data], which must be valid.
static func from_data(p_data: Dictionary) -> Content:
	var content := Content.from_data(p_data)
	assert(content.errors.is_empty(), "test content is valid: %s" % "; ".join(content.errors))
	return content
