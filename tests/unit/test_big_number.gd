extends GutTest
## BigNumber holds values far past 64-bit limits (the game has no end).

const INT64_MAX := 9223372036854775807


func test_adds_values_past_float_range() -> void:
	var a := BigNumber.new(5.0, 400)
	var b := BigNumber.new(7.0, 400)
	var sum := a.add(b)
	assert_true(sum.equals(BigNumber.new(1.2, 401)), "5e400 + 7e400 = 1.2e401, got %s" % sum)


func test_adding_a_much_smaller_value_keeps_the_larger_value() -> void:
	var big := BigNumber.new(1.0, 100)
	assert_true(big.add(BigNumber.from_int(1)).equals(big))
	assert_true(BigNumber.from_int(1).add(big).equals(big))


func test_adds_small_integers_exactly() -> void:
	assert_true(BigNumber.from_int(999).add(BigNumber.from_int(1)).equals(BigNumber.from_int(1000)))
	assert_true(BigNumber.from_int(3).add(BigNumber.ZERO).equals(BigNumber.from_int(3)))


func test_subtracts_small_integers_exactly() -> void:
	assert_true(BigNumber.from_int(100).sub(BigNumber.from_int(10)).equals(BigNumber.from_int(90)))
	assert_true(BigNumber.from_int(10).sub(BigNumber.from_int(10)).is_zero())
	assert_true(BigNumber.from_int(3).sub(BigNumber.from_int(5)).equals(BigNumber.from_int(-2)))


func test_subtracts_values_past_float_range() -> void:
	var difference := BigNumber.new(1.2, 401).sub(BigNumber.new(7.0, 400))
	assert_true(difference.equals(BigNumber.new(5.0, 400)), "1.2e401 - 7e400 = 5e400, got %s" % difference)


func test_subtracting_a_much_smaller_value_keeps_the_larger_value() -> void:
	var big := BigNumber.new(1.0, 100)
	assert_true(big.sub(BigNumber.from_int(1)).equals(big))


func test_scaled_power_does_not_overflow() -> void:
	assert_almost_eq(BigNumber.scaled_power(BigNumber.from_int(10), 2.0, 3).to_float(), 80.0, 1e-9)
	assert_true(BigNumber.scaled_power(BigNumber.from_int(7), 1.5, 0).equals(BigNumber.from_int(7)))
	# 1.15^100000 is about 10^6069.
	var huge := BigNumber.scaled_power(BigNumber.from_int(10), 1.15, 100_000)
	assert_eq(huge.exponent, 6070)


func test_round_trips_through_plain_data() -> void:
	var value := BigNumber.new(-4.25, 1234)
	assert_true(BigNumber.from_data(value.to_data()).equals(value))


func test_multiplies_past_64_bit_limits() -> void:
	var max_int := BigNumber.from_int(INT64_MAX)
	var product := max_int.mul(max_int)
	# (2^63 - 1)^2 is about 8.507e37.
	assert_eq(product.exponent, 37)
	assert_almost_eq(product.mantissa, 8.507059, 0.000001)
	assert_true(product.is_greater_than(max_int))


func test_multiplies_past_float_range() -> void:
	var product := BigNumber.new(2.0, 300).mul(BigNumber.new(5.0, 300))
	assert_true(product.equals(BigNumber.new(1.0, 601)), "2e300 * 5e300 = 1e601, got %s" % product)


func test_multiplying_by_zero_gives_zero() -> void:
	assert_true(BigNumber.new(4.0, 900).mul(BigNumber.ZERO).is_zero())


func test_compares_by_exponent_then_mantissa() -> void:
	var small := BigNumber.new(9.9, 599)
	var large := BigNumber.new(1.0, 600)
	assert_eq(small.compare(large), -1)
	assert_eq(large.compare(small), 1)
	assert_eq(large.compare(BigNumber.new(1.0, 600)), 0)
	assert_true(large.is_greater_than(small))
	assert_true(small.is_less_than(large))
	assert_true(BigNumber.new(2.0, 5).is_greater_than(BigNumber.new(1.5, 5)))


func test_compares_zero_and_negative_values() -> void:
	var negative := BigNumber.from_int(-5)
	assert_true(negative.is_less_than(BigNumber.ZERO))
	assert_true(BigNumber.ZERO.is_less_than(BigNumber.new(1.0, -3)))
	assert_true(BigNumber.new(-1.0, 50).is_less_than(negative), "-1e50 < -5")


func test_normalizes_the_mantissa() -> void:
	var n := BigNumber.new(1234.5, 0)
	assert_almost_eq(n.mantissa, 1.2345, 0.0000001)
	assert_eq(n.exponent, 3)
	assert_true(BigNumber.from_int(0).is_zero())


func test_formats_small_values_as_plain_numbers() -> void:
	assert_eq(BigNumber.ZERO.format(), "0")
	assert_eq(BigNumber.from_int(7).format(), "7")
	assert_eq(BigNumber.from_int(999).format(), "999")
	assert_eq(BigNumber.from_float(12.5).format(), "12.5")
	assert_eq(BigNumber.from_float(0.125).format(), "0.13")
	assert_eq(BigNumber.from_int(-42).format(), "-42")


func test_formats_thousands_and_up_with_short_suffixes() -> void:
	assert_eq(BigNumber.from_int(1000).format(), "1.00K")
	assert_eq(BigNumber.from_int(12_345).format(), "12.3K")
	assert_eq(BigNumber.from_int(123_456).format(), "123K")
	assert_eq(BigNumber.from_int(4_560_000).format(), "4.56M")
	assert_eq(BigNumber.from_int(INT64_MAX).format(), "9.22Qi")
	assert_eq(BigNumber.new(1.0, 33).format(), "1.00Dc")


func test_formats_rounding_up_into_the_next_suffix() -> void:
	assert_eq(BigNumber.from_float(999.999).format(), "1.00K")
	assert_eq(BigNumber.from_int(999_999).format(), "1.00M")


func test_formats_very_large_values_in_scientific_notation() -> void:
	assert_eq(BigNumber.new(1.0, 36).format(), "1.00e36")
	assert_eq(BigNumber.new(4.567, 600).format(), "4.57e600")
	assert_eq(BigNumber.new(-2.0, 600).format(), "-2.00e600")


func test_formats_huge_exponents_in_a_short_form() -> void:
	# The exponent itself gets too long to read, so show only its size.
	assert_eq(BigNumber.new(3.0, 1_234_567).format(), "e1.23e6")
	assert_eq(BigNumber.new(3.0, 999_999).format(), "3.00e999999")
