class_name TestContent
extends RefCounted
## Small content for tests, so tests do not depend on the game's data files.


static func colors_data() -> Dictionary:
	return {"colors": [
		{"id": "red", "name": "Red", "symbol": "square", "display": "#d64545", "recipe": {}},
		{"id": "yellow", "name": "Yellow", "symbol": "triangle", "display": "#f2c230", "recipe": {}},
		{"id": "blue", "name": "Blue", "symbol": "circle", "display": "#3a6fd8", "recipe": {}},
	]}


static func balance_data(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Dictionary:
	return {"factory": {
		"widget_time_ms": widget_time_ms,
		"output_bay_capacity": output_bay_capacity,
	}}


## Content with one widget per [param widget_time_ms] and an output bay of
## [param output_bay_capacity].
static func make(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	var content := Content.from_data(colors_data(), balance_data(widget_time_ms, output_bay_capacity))
	assert(content.errors.is_empty(), "test content is valid")
	return content
