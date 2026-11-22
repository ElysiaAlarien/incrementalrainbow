extends GutTest
## The fast paths of BigNumber (#55) give the same bits as the algorithm
## before them, which [method _old_normalized] keeps.

const SEED := 55


func test_a_new_number_has_the_same_bits_as_before() -> void:
	var differences := PackedStringArray()
	for value in _values():
		for exponent: int in [0, 7, -3]:
			var number := BigNumber.new(value, exponent)
			var old := _old_normalized(value, exponent)
			if number.mantissa != old[0] or number.exponent != old[1]:
				differences.append("%s e%d" % [value, exponent])
	assert_eq(differences, PackedStringArray(), "values with other bits than before")


func test_times_float_is_the_same_as_mul_of_from_float() -> void:
	var differences := PackedStringArray()
	var bases: Array[BigNumber] = [BigNumber.from_float(15.0), BigNumber.new(3.7, 12), BigNumber.ZERO,
		BigNumber.from_float(-2.5)]
	for base in bases:
		for value in _values():
			var fast := base.times_float(value)
			var slow := base.mul(BigNumber.from_float(value))
			if fast.mantissa != slow.mantissa or fast.exponent != slow.exponent:
				differences.append("%s times %s" % [base, value])
	assert_eq(differences, PackedStringArray(), "products with other bits than mul")


## Values in each fast path, at and near its bounds, between the paths, and
## far from them, with both signs.
func _values() -> PackedFloat64Array:
	var values := PackedFloat64Array([0.0, 1.0, 9.5, 10.5, 95.0, 0.105, 0.95, 9.999999999999999, 10.0,
		0.1, 100.0, 1e-300, 1e300, 0.99999999999999, 1.00000000000001, 123456.789, 7e-5])
	for bound: float in [1.0, 9.5, 10.5, 95.0, 0.105, 0.95]:
		values.append(_next_float(bound, -1))
		values.append(_next_float(bound, 1))
	var rng := SimRng.new(SEED)
	for i in 3000:
		# Sizes from 1e-3 to 1e3, so most values are in a fast path.
		values.append(pow(10.0, rng.randf() * 6.0 - 3.0))
	var count := values.size()
	for i in count:
		values.append(-values[i])
	return values


## The float next to the positive [param value], up for a [param step] of 1
## and down for -1.
static func _next_float(value: float, step: int) -> float:
	var bytes := PackedFloat64Array([value]).to_byte_array()
	bytes.encode_s64(0, bytes.decode_s64(0) + step)
	return bytes.decode_double(0)


## BigNumber's normalization before #55: [mantissa, exponent].
static func _old_normalized(p_mantissa: float, p_exponent: int) -> Array:
	if p_mantissa == 0.0 or is_nan(p_mantissa) or is_inf(p_mantissa):
		return [0.0, 0]
	var shift := floori(log(absf(p_mantissa)) / log(10.0))
	var m := p_mantissa * pow(10.0, -shift) if shift < 0 else p_mantissa / pow(10.0, shift)
	var e := p_exponent + shift
	if absf(m) >= 10.0:
		m /= 10.0
		e += 1
	elif absf(m) < 1.0:
		m *= 10.0
		e -= 1
	m = roundf(m * 1e14) / 1e14
	if absf(m) >= 10.0:
		m /= 10.0
		e += 1
	return [m, e]
