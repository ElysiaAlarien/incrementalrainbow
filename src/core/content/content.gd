class_name Content
extends RefCounted
## The game content: colors, symbols, recipes, markets, transport tiers, and
## balance values. Read-only.
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
	"markets": "markets.json",
	"transport": "transport.json",
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
## The money that automatic transport for one link costs.
var automatic_transport_cost: BigNumber:
	get:
		return _automatic_transport_cost

var _errors: PackedStringArray = []
var _factory_balance := FactoryBalance.new(0, 0, BigNumber.ZERO, 1.0, BigNumber.ZERO)
var _starting_money := BigNumber.ZERO
var _automatic_transport_cost := BigNumber.ZERO
var _colors: Array[ColorDef] = []
var _colors_by_id: Dictionary[StringName, ColorDef] = {}
var _markets: Array[MarketDef] = []
var _markets_by_id: Dictionary[StringName, MarketDef] = {}
var _tiers: Array[TransportTier] = []
var _tiers_by_id: Dictionary[StringName, TransportTier] = {}


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
	# Markets name colors, so parse them after the colors.
	content._parse_markets(data.get("markets", {}))
	content._parse_transport(data.get("transport", {}))
	return content


## All colors, in data order.
func colors() -> Array[ColorDef]:
	return _colors.duplicate()


## The color with [param id], or null.
func color(id: StringName) -> ColorDef:
	return _colors_by_id.get(id)


## All markets, in data order. A run starts with all of them open.
func markets() -> Array[MarketDef]:
	return _markets.duplicate()


## The market with [param id], or null.
func market(id: StringName) -> MarketDef:
	return _markets_by_id.get(id)


## All transport tiers, lowest first. A new link uses the first one.
func transport_tiers() -> Array[TransportTier]:
	return _tiers.duplicate()


## The transport tier with [param id], or null.
func transport_tier(id: StringName) -> TransportTier:
	return _tiers_by_id.get(id)


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
		_starting_money = _read_money(run, "starting_money", "run")
	else:
		_errors.append("balance.json: \"run\" must be an object")
	var factory: Variant = data.get("factory", {})
	if not factory is Dictionary:
		_errors.append("balance.json: \"factory\" must be an object")
		return
	_factory_balance = FactoryBalance.new(
		_read_positive_int(factory, "widget_time_ms", "factory"),
		_read_positive_int(factory, "output_bay_capacity", "factory"),
		_read_money(factory, "production_line_cost", "factory"),
		_read_number(factory, "production_line_cost_growth", "factory", 1.0),
		_read_money(factory, "build_cost", "factory"))


func _parse_markets(data: Dictionary) -> void:
	for entry in _read_entries(data, "markets.json", "markets", "market"):
		var id := StringName(entry.id)
		var def := MarketDef.new(id, entry.name, _parse_prices(id, entry.get("prices", {})))
		_markets.append(def)
		_markets_by_id[id] = def


func _parse_prices(market_id: StringName, data: Variant) -> Dictionary[StringName, BigNumber]:
	var prices: Dictionary[StringName, BigNumber] = {}
	if not data is Dictionary:
		_errors.append("%s: prices must be an object" % market_id)
		return prices
	for key: Variant in data:
		var color_id := StringName(str(key))
		if not _colors_by_id.has(color_id):
			_errors.append("%s: price for %s, which is not a color" % [market_id, color_id])
		elif _is_number(data[key]) and data[key] > 0:
			prices[color_id] = BigNumber.from_float(float(data[key]))
		else:
			_errors.append("%s: price for %s must be a positive number" % [market_id, color_id])
	for def in _colors:
		if not data.has(String(def.id)) and not data.has(def.id):
			_errors.append("%s: no price for %s" % [market_id, def.id])
	return prices


func _parse_transport(data: Dictionary) -> void:
	_automatic_transport_cost = _read_money(data, "automatic_transport_cost", "transport")
	for entry in _read_entries(data, "transport.json", "tiers", "transport tier"):
		var id := StringName(entry.id)
		var tier := TransportTier.new(id, entry.name,
			_read_positive_int(entry, "transit_time_ms", id),
			_read_money(entry, "shipment_cost", id))
		_tiers.append(tier)
		_tiers_by_id[id] = tier


## The entries of the list [param list_key] in [param file]: objects, each with
## a unique id and a name. Reports a missing or empty list, an entry that is not
## an object, a missing or duplicate id (and skips that entry), and a missing
## name. In each returned entry, "id" and "name" are Strings.
func _read_entries(data: Dictionary, file: String, list_key: String, noun: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var list: Variant = data.get(list_key)
	if not list is Array:
		_errors.append("%s: \"%s\" must be a list" % [file, list_key])
		return entries
	if list.is_empty():
		_errors.append("%s: there must be at least one %s" % [file, noun])
	var seen := {}
	for entry: Variant in list:
		if not entry is Dictionary:
			_errors.append("%s: each %s must be an object" % [file, noun])
			continue
		var id := str(entry.get("id", ""))
		if id.is_empty():
			_errors.append("%s: a %s has no id" % [file, noun])
			continue
		if seen.has(id):
			_errors.append("duplicate %s id %s" % [noun, id])
			continue
		seen[id] = true
		var checked: Dictionary = entry.duplicate()
		checked.id = id
		checked.name = str(entry.get("name", ""))
		if checked.name.is_empty():
			_errors.append("%s: name is missing" % id)
		entries.append(checked)
	return entries


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
## A money value: a number of 0 or more.
func _read_money(section: Dictionary, key: String, section_name: String) -> BigNumber:
	return BigNumber.from_float(_read_number(section, key, section_name, 0.0))


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


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
