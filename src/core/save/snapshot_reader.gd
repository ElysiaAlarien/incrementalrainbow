class_name SnapshotReader
extends RefCounted
## Reads one object of saved core state, and checks each value as it reads it.
##
## A save comes from a file, so any value can be missing or wrong. A read never
## fails hard: it records a problem with the path of the value, such as
## [code]state.factories[1].color[/code], and returns a safe default. After the
## whole state is read, check [method errors]. All readers made from one root
## share its list of problems.
##
## JSON has only one number type, so a whole number can come back as a float.
## [method integer] accepts it when it is whole and exact.

## The largest whole number that a JSON number (a 64-bit float) holds exactly.
const MAX_EXACT_INT := 1 << 53
const _MAX_U32 := 0xFFFFFFFF

var _data: Dictionary
var _path: String
## Shared by this reader and all readers made from it.
var _errors: Array[String]


func _init(p_data: Dictionary, p_path: String = "state") -> void:
	_data = p_data
	_path = p_path
	_errors = []


## Every problem found so far, by all readers made from the same root.
func errors() -> PackedStringArray:
	return PackedStringArray(_errors)


## Records a problem with the value at [param key], for checks that need
## more than one value or the content, such as an unknown color.
func fail(key: String, problem: String) -> void:
	_problem(_key_path(key), problem)


## A whole number from [param minimum] to [param maximum].
func integer(key: String, minimum: int = 0, maximum: int = MAX_EXACT_INT) -> int:
	if not _has(key):
		return minimum
	return _to_integer(_data[key], _key_path(key), minimum, maximum)


## A text id, such as a color id. It cannot be empty.
func text_id(key: String) -> StringName:
	if not _has(key):
		return &""
	var value: Variant = _data[key]
	if not value is String or value.is_empty():
		fail(key, "must be a text id, but it is %s" % _describe(value))
		return &""
	return StringName(value)


## A text id that can be empty, for a choice that can be none.
func optional_text_id(key: String) -> StringName:
	if not _has(key):
		return &""
	var value: Variant = _data[key]
	if not value is String:
		fail(key, "must be a text id or \"\", but it is %s" % _describe(value))
		return &""
	return StringName(value)


## A list of text ids, none of them empty.
func text_id_list(key: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not _has(key):
		return ids
	var value: Variant = _data[key]
	if not value is Array:
		fail(key, "must be a list, but it is %s" % _describe(value))
		return ids
	for i in value.size():
		var item: Variant = value[i]
		if item is String and not item.is_empty():
			ids.append(StringName(item))
		else:
			_problem("%s[%d]" % [_key_path(key), i], "must be a text id, but it is %s" % _describe(item))
	return ids


## A list of exactly [param count] whole numbers, each in [0, 2^32).
func u32_list(key: String, count: int) -> PackedInt64Array:
	var numbers := PackedInt64Array()
	numbers.resize(count)
	if not _has(key):
		return numbers
	var value: Variant = _data[key]
	if not value is Array or value.size() != count:
		fail(key, "must be a list of %d whole numbers, but it is %s" % [count, _describe(value)])
		return numbers
	for i in count:
		numbers[i] = _to_integer(value[i], "%s[%d]" % [_key_path(key), i], 0, _MAX_U32)
	return numbers


## A [BigNumber] in the form of [method BigNumber.to_data]:
## [code][mantissa, exponent][/code], with a mantissa of 0 or with a size in
## [1, 10).
func big_number(key: String) -> BigNumber:
	if not _has(key):
		return BigNumber.ZERO
	var value: Variant = _data[key]
	if not value is Array or value.size() != 2:
		fail(key, "must be a list of a mantissa and an exponent, but it is %s" % _describe(value))
		return BigNumber.ZERO
	var path := _key_path(key)
	var mantissa: Variant = value[0]
	if not (mantissa is float or mantissa is int) or not is_finite(mantissa) \
			or (mantissa != 0 and (absf(mantissa) < 1.0 or absf(mantissa) >= 10.0)):
		_problem(path + "[0]", "must be a mantissa of 0 or from 1 to less than 10, but it is %s" % _describe(mantissa))
		return BigNumber.ZERO
	var exponent := _to_integer(value[1], path + "[1]", -MAX_EXACT_INT, MAX_EXACT_INT)
	return BigNumber.new(float(mantissa), exponent)


## A list of objects, each read by its own reader.
func objects(key: String) -> Array[SnapshotReader]:
	var readers: Array[SnapshotReader] = []
	if not _has(key):
		return readers
	var value: Variant = _data[key]
	if not value is Array:
		fail(key, "must be a list, but it is %s" % _describe(value))
		return readers
	for i in value.size():
		var item: Variant = value[i]
		var item_path := "%s[%d]" % [_key_path(key), i]
		if item is Dictionary:
			var reader := SnapshotReader.new(item, item_path)
			reader._errors = _errors
			readers.append(reader)
		else:
			_problem(item_path, "must be an object, but it is %s" % _describe(item))
	return readers


## Records a problem when [param key] is missing.
func _has(key: String) -> bool:
	if _data.has(key):
		return true
	fail(key, "is missing")
	return false


func _to_integer(value: Variant, path: String, minimum: int, maximum: int) -> int:
	var number := 0
	if value is int:
		number = value
	elif value is float and is_finite(value) and value == floorf(value) and absf(value) <= MAX_EXACT_INT:
		number = int(value)
	else:
		_problem(path, "must be a whole number, but it is %s" % _describe(value))
		return minimum
	if number < minimum or number > maximum:
		_problem(path, "must be from %d to %d, but it is %d" % [minimum, maximum, number])
		return minimum
	return number


func _problem(path: String, problem: String) -> void:
	_errors.append("%s: %s" % [path, problem])


func _key_path(key: String) -> String:
	return "%s.%s" % [_path, key]


static func _describe(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Array:
		return "a list of %d" % value.size()
	if value is Dictionary:
		return "an object"
	if value is String:
		return "\"%s\"" % value
	return str(value)
