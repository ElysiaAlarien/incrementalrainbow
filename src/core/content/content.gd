class_name Content
extends RefCounted
## The game content: colors, symbols, recipes, and balance values. Read-only.
##
## Content is data, not code. It loads from JSON files in [constant DEFAULT_DIR]
## (see ADR-0007), and the simulation gets it at construction, so tests can use
## small content of their own. A load never fails hard: check [member errors].
##
## To add a content file, add it to [constant FILES] and parse its section in
## [method from_data].

const DEFAULT_DIR := "res://data"
## Section name to file name. [method from_data] takes one Dictionary per section.
const FILES: Dictionary[String, String] = {
	"colors": "colors.json",
	"balance": "balance.json",
}

## Problems found in the data. Empty when the content is valid.
var errors: PackedStringArray:
	get:
		return _errors.duplicate()
var factory_balance: FactoryBalance:
	get:
		return _factory_balance
## The money the player has at the start of a run.
var starting_money: BigNumber:
	get:
		return _starting_money

var _errors: PackedStringArray = []
var _factory_balance := FactoryBalance.new(0, 0)
var _starting_money := BigNumber.ZERO
var _colors: Array[ColorDef] = []
var _colors_by_id: Dictionary[StringName, ColorDef] = {}


static func load_dir(dir_path: String) -> Content:
	var data := {}
	var load_errors: PackedStringArray = []
	for section in FILES:
		data[section] = _read_json(dir_path.path_join(FILES[section]), load_errors)
	if not load_errors.is_empty():
		var failed := Content.new()
		failed._errors = load_errors
		return failed
	return from_data(data)


## Builds content from parsed data: one Dictionary per section of [constant FILES].
static func from_data(data: Dictionary) -> Content:
	var content := Content.new()
	content._parse_colors(data.get("colors", {}))
	content._parse_balance(data.get("balance", {}))
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
		_errors.append("colors.json: \"colors\" must be a list")
		return
	var symbol_owner := {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			_errors.append("colors.json: each color must be an object")
			continue
		var id := StringName(str(entry.get("id", "")))
		if id == &"":
			_errors.append("colors.json: a color has no id")
			continue
		if _colors_by_id.has(id):
			_errors.append("duplicate color id %s" % id)
			continue
		var color_name := str(entry.get("name", ""))
		if color_name.is_empty():
			_errors.append("%s: name is missing" % id)
		var symbol := StringName(str(entry.get("symbol", "")))
		if symbol == &"":
			_errors.append("%s: symbol is missing" % id)
		elif symbol_owner.has(symbol):
			_errors.append("%s: symbol %s is already used by %s" % [id, symbol, symbol_owner[symbol]])
		else:
			symbol_owner[symbol] = id
		var display := str(entry.get("display", ""))
		var display_color := Color.BLACK
		if Color.html_is_valid(display):
			display_color = Color.html(display)
		else:
			_errors.append("%s: bad display color %s" % [id, display])
		var def := ColorDef.new(id, color_name, symbol, display_color, _parse_recipe(id, entry.get("recipe", {})))
		_colors.append(def)
		_colors_by_id[id] = def
	# Inputs can name colors later in the file, so check them after all are read.
	for def in _colors:
		for input in def.recipe:
			if not _colors_by_id.has(input):
				_errors.append("%s: recipe input %s is not a color" % [def.id, input])


func _parse_recipe(color_id: StringName, data: Variant) -> Dictionary[StringName, int]:
	var recipe: Dictionary[StringName, int] = {}
	if not data is Dictionary:
		_errors.append("%s: recipe must be an object" % color_id)
		return recipe
	for input: Variant in data:
		var count: Variant = data[input]
		if _is_positive_int(count):
			recipe[StringName(str(input))] = int(count)
		else:
			_errors.append("%s: recipe count for %s must be a positive integer" % [color_id, input])
	return recipe


func _parse_balance(data: Dictionary) -> void:
	var run: Variant = data.get("run", {})
	if run is Dictionary:
		_starting_money = BigNumber.from_float(_read_number(run, "starting_money", "run", 0.0))
	else:
		_errors.append("balance.json: \"run\" must be an object")
	var factory: Variant = data.get("factory", {})
	if not factory is Dictionary:
		_errors.append("balance.json: \"factory\" must be an object")
		return
	_factory_balance = FactoryBalance.new(
		_read_positive_int(factory, "widget_time_ms", "factory"),
		_read_positive_int(factory, "output_bay_capacity", "factory"),
		BigNumber.from_float(_read_number(factory, "production_line_cost", "factory", 0.0)),
		_read_number(factory, "production_line_cost_growth", "factory", 1.0))


func _read_positive_int(section: Dictionary, key: String, section_name: String) -> int:
	var value: Variant = section.get(key)
	if not _is_positive_int(value):
		_errors.append("%s.%s must be a positive integer" % [section_name, key])
		return 0
	return int(value)


## Reads a finite number that is at least [param minimum]. On an error, returns
## [param minimum].
func _read_number(section: Dictionary, key: String, section_name: String, minimum: float) -> float:
	var value: Variant = section.get(key)
	if (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum:
		return float(value)
	_errors.append("%s.%s must be a number of at least %s" % [section_name, key, String.num(minimum)])
	return minimum


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
