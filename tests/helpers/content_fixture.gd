class_name ContentFixture
extends RefCounted
## Small content for tests, so tests do not depend on the game's data files.


static func colors_data() -> Dictionary:
	return {"colors": [
		{"id": "red", "name": "Red", "symbol": "square", "display": "#d64545", "recipe": {}},
		{"id": "yellow", "name": "Yellow", "symbol": "triangle", "display": "#f2c230", "recipe": {}},
		{"id": "blue", "name": "Blue", "symbol": "circle", "display": "#3a6fd8", "recipe": {}},
	]}


## Balance data: 100 starting money and a flat production line cost of 10.
## [param overrides] replaces values by key, such as
## [code]{"starting_money": 15, "production_line_cost_growth": 2.0}[/code].
static func balance_data(widget_time_ms: int = 1000, output_bay_capacity: int = 10,
		overrides: Dictionary = {}) -> Dictionary:
	var run := {"starting_money": 100}
	var factory := {
		"widget_time_ms": widget_time_ms,
		"output_bay_capacity": output_bay_capacity,
		"production_line_cost": 10,
		"production_line_cost_growth": 1.0,
	}
	for key: String in overrides:
		var section := run if run.has(key) else factory
		assert(section.has(key), "unknown balance key %s" % key)
		section[key] = overrides[key]
	return {"run": run, "factory": factory}


## Data for [method Content.from_data], with each section replaceable.
static func data(colors: Dictionary = colors_data(), balance: Dictionary = balance_data()) -> Dictionary:
	return {"colors": colors, "balance": balance}


## Content with one widget per [param widget_time_ms] for each production line,
## an output bay of [param output_bay_capacity], 100 starting money, and a flat
## production line cost of 10.
static func make(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	return make_with_balance(balance_data(widget_time_ms, output_bay_capacity))


## Content with the test colors and [param balance] from [method balance_data].
static func make_with_balance(balance: Dictionary) -> Content:
	var content := Content.from_data(data(colors_data(), balance))
	assert(content.errors.is_empty(), "test content is valid")
	return content
