class_name Content
extends RefCounted
## The game content: colors, symbols, recipes, and balance values.
##
## Content is data, not code. It loads from JSON files in [constant DEFAULT_DIR]
## (see ADR-0007), and the simulation gets it at construction, so tests can use
## small content of their own. A load never fails hard: check [member errors].

const DEFAULT_DIR := "res://data"
const COLORS_FILE := "colors.json"
const BALANCE_FILE := "balance.json"

## Problems found in the data. Empty when the content is valid.
var errors: PackedStringArray = []

## Time for one production line to make one widget. Placeholder value.
var widget_time_ms: int
## How many widgets an output bay holds. Placeholder value.
var output_bay_capacity: int

var _colors: Array[ColorDef] = []
var _colors_by_id: Dictionary[StringName, ColorDef] = {}


static func load_dir(dir_path: String) -> Content:
	var load_errors: PackedStringArray = []
	var colors_data := _read_json(dir_path.path_join(COLORS_FILE), load_errors)
	var balance_data := _read_json(dir_path.path_join(BALANCE_FILE), load_errors)
	if not load_errors.is_empty():
		var failed := Content.new()
		failed.errors = load_errors
		return failed
	return from_data(colors_data, balance_data)


static func from_data(colors_data: Dictionary, balance_data: Dictionary) -> Content:
	var content := Content.new()
	content._parse_colors(colors_data)
	content._parse_balance(balance_data)
	return content


## All colors, in data order.
func colors() -> Array[ColorDef]:
	return _colors.duplicate()


## The color with [param id], or null.
func color(id: StringName) -> ColorDef:
	return _colors_by_id.get(id)


func _parse_colors(data: Dictionary) -> void:
	var entries: Variant = data.get("colors")
	if not entries is Array:
		errors.append("colors.json: \"colors\" must be a list")
		return
	var symbol_owner := {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			errors.append("colors.json: each color must be an object")
			continue
		var color := ColorDef.new()
		color.id = StringName(str(entry.get("id", "")))
		var where := String(color.id)
		if color.id == &"":
			errors.append("colors.json: a color has no id")
			continue
		if _colors_by_id.has(color.id):
			errors.append("duplicate color id %s" % color.id)
			continue
		color.name = str(entry.get("name", ""))
		if color.name.is_empty():
			errors.append("%s: name is missing" % where)
		color.symbol = StringName(str(entry.get("symbol", "")))
		if color.symbol == &"":
			errors.append("%s: symbol is missing" % where)
		elif symbol_owner.has(color.symbol):
			errors.append("%s: symbol %s is already used by %s" % [where, color.symbol, symbol_owner[color.symbol]])
		else:
			symbol_owner[color.symbol] = color.id
		var display := str(entry.get("display", ""))
		if not Color.html_is_valid(display):
			errors.append("%s: bad display color %s" % [where, display])
		else:
			color.display_color = Color.html(display)
		var recipe: Variant = entry.get("recipe", {})
		if recipe is Dictionary:
			for input: Variant in recipe:
				var count: Variant = recipe[input]
				if not _is_positive_int(count):
					errors.append("%s: recipe count for %s must be a positive integer" % [where, input])
				else:
					color.recipe[StringName(str(input))] = int(count)
		else:
			errors.append("%s: recipe must be an object" % where)
		_colors.append(color)
		_colors_by_id[color.id] = color
	# Inputs can name colors later in the file, so check them after all are read.
	for color in _colors:
		for input in color.recipe:
			if not _colors_by_id.has(input):
				errors.append("%s: recipe input %s is not a color" % [color.id, input])


func _parse_balance(data: Dictionary) -> void:
	var factory: Variant = data.get("factory", {})
	if not factory is Dictionary:
		errors.append("balance.json: \"factory\" must be an object")
		return
	widget_time_ms = _read_positive_int(factory, "widget_time_ms", "factory")
	output_bay_capacity = _read_positive_int(factory, "output_bay_capacity", "factory")


func _read_positive_int(section: Dictionary, key: String, section_name: String) -> int:
	var value: Variant = section.get(key)
	if not _is_positive_int(value):
		errors.append("%s.%s must be a positive integer" % [section_name, key])
		return 0
	return int(value)


## JSON numbers load as floats, so accept a float that holds a whole number.
static func _is_positive_int(value: Variant) -> bool:
	if value is int:
		return value > 0
	if value is float:
		return value > 0.0 and value == floorf(value) and value < 9.0e15
	return false


static func _read_json(path: String, load_errors: PackedStringArray) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("cannot read %s: file not found" % path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		load_errors.append("cannot read %s: %s at line %d" % [path, json.get_error_message(), json.get_error_line()])
		return {}
	if not json.data is Dictionary:
		load_errors.append("cannot read %s: the top level must be an object" % path)
		return {}
	return json.data
