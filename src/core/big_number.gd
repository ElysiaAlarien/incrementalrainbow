class_name BigNumber
extends RefCounted
## An immutable number that holds values far past 64-bit limits.
##
## The value is [code]mantissa * 10^exponent[/code]. The mantissa is a float in
## [1, 10) (or (-10, -1] for negative values), and the exponent is an int, so the
## largest value is about 10^(9.2e18). The mantissa keeps about 15 significant
## digits, which is enough for an incremental game. See ADR-0005.
##
## GDScript has no operator overloading, so use the methods: [method add],
## [method mul], [method compare], and [method format].

## Above this exponent difference, the smaller value has no effect on a sum.
const _MAX_EXPONENT_GAP := 17
## Short suffixes for each group of three digits, starting at 10^3.
const _SUFFIXES: PackedStringArray = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
## Above this exponent, the format shows only the size of the exponent.
const _LONG_EXPONENT := 1_000_000

static var ZERO := BigNumber.new(0.0, 0)

var mantissa: float:
	get:
		return _mantissa
var exponent: int:
	get:
		return _exponent

var _mantissa: float
var _exponent: int


## Makes the number [param p_mantissa] * 10^[param p_exponent]. The mantissa can
## have any size; the result is normalized.
func _init(p_mantissa: float = 0.0, p_exponent: int = 0) -> void:
	if p_mantissa == 0.0 or is_nan(p_mantissa) or is_inf(p_mantissa):
		assert(p_mantissa == 0.0, "BigNumber mantissa must be finite, got %s" % p_mantissa)
		_mantissa = 0.0
		_exponent = 0
		return
	var shift := floori(log(absf(p_mantissa)) / log(10.0))
	var m := p_mantissa / pow(10.0, shift)
	var e := p_exponent + shift
	# log() can be off by one near powers of ten.
	if absf(m) >= 10.0:
		m /= 10.0
		e += 1
	elif absf(m) < 1.0:
		m *= 10.0
		e -= 1
	_mantissa = m
	_exponent = e


static func from_int(value: int) -> BigNumber:
	return BigNumber.new(float(value), 0)


static func from_float(value: float) -> BigNumber:
	return BigNumber.new(value, 0)


func is_zero() -> bool:
	return _mantissa == 0.0


func is_negative() -> bool:
	return _mantissa < 0.0


func add(other: BigNumber) -> BigNumber:
	if other.is_zero():
		return self
	if is_zero():
		return other
	var larger := self if _exponent >= other._exponent else other
	var smaller := other if larger == self else self
	var gap := larger._exponent - smaller._exponent
	if gap > _MAX_EXPONENT_GAP:
		return larger
	return BigNumber.new(larger._mantissa + smaller._mantissa / pow(10.0, gap), larger._exponent)


func mul(other: BigNumber) -> BigNumber:
	if is_zero() or other.is_zero():
		return ZERO
	return BigNumber.new(_mantissa * other._mantissa, _exponent + other._exponent)


## Returns -1 if this number is less than [param other], 0 if equal, and 1 if greater.
func compare(other: BigNumber) -> int:
	var sign_a := signi(int(signf(_mantissa)))
	var sign_b := signi(int(signf(other._mantissa)))
	if sign_a != sign_b:
		return 1 if sign_a > sign_b else -1
	if sign_a == 0:
		return 0
	var magnitude := 0
	if _exponent != other._exponent:
		magnitude = 1 if _exponent > other._exponent else -1
	elif absf(_mantissa) != absf(other._mantissa):
		magnitude = 1 if absf(_mantissa) > absf(other._mantissa) else -1
	return magnitude * sign_a


func equals(other: BigNumber) -> bool:
	return compare(other) == 0


func is_greater_than(other: BigNumber) -> bool:
	return compare(other) > 0


func is_less_than(other: BigNumber) -> bool:
	return compare(other) < 0


## Returns the value as a float, or +/-INF when it is too large for a float.
func to_float() -> float:
	return _mantissa * pow(10.0, _exponent)


## Returns a short text that stays readable at any size: "999", "12.5",
## "4.56M", "1.00e36", or "e1.23e6" when the exponent is too long to read.
func format() -> String:
	if _exponent < 3:
		var rounded := snappedf(to_float(), 0.01)
		if absf(rounded) < 1000.0:
			return _format_plain(rounded)
	var sign_text := "-" if is_negative() else ""
	# Round to three significant digits first, because rounding can carry into
	# the next power of ten (999.9K becomes 1.00M).
	var m := snappedf(absf(_mantissa), 0.01)
	var e := _exponent
	if m >= 10.0:
		m /= 10.0
		e += 1
	if e >= _LONG_EXPONENT:
		return sign_text + "e" + BigNumber.from_int(e)._format_scientific()
	var group := e / 3
	if group <= _SUFFIXES.size():
		var digits_before_point := e % 3
		var value := m * pow(10.0, digits_before_point)
		var text := "%.*f" % [2 - digits_before_point, value]
		return sign_text + text + _SUFFIXES[group - 1]
	return sign_text + BigNumber.new(m, e)._format_scientific()


func _to_string() -> String:
	return "%se%d" % [_mantissa, _exponent]


## "1.23e45" for a positive number that is already rounded to three digits.
func _format_scientific() -> String:
	var m := snappedf(_mantissa, 0.01)
	var e := _exponent
	if m >= 10.0:
		m /= 10.0
		e += 1
	return "%.2fe%d" % [m, e]


static func _format_plain(value: float) -> String:
	var text := "%.2f" % value
	text = text.rstrip("0").rstrip(".")
	return "0" if text == "-0" else text
