extends GutTest
## The rules of the market generator come from the "generator" object of
## markets.json, and the content checks them.


func _errors(generator: Variant, ids: PackedStringArray = ["millbrook"],
		balance: Dictionary = ContentFixture.balance_data()) -> PackedStringArray:
	var markets := ContentFixture.markets_data(ContentFixture.PRICE, ContentFixture.colors_data(), ids)
	markets.generator = generator
	return Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance, markets)).errors


func _has_error(errors: PackedStringArray, part: String) -> bool:
	for error in errors:
		if error.contains(part):
			return true
	return false


func test_markets_with_no_generator_have_no_generated_markets() -> void:
	var content := ContentFixture.make()

	assert_null(content.market_generator)
	assert_eq(Simulation.new(content, 1).markets().size(), 1)


func test_reads_the_generator_rules() -> void:
	var markets := ContentFixture.remote_markets_data()
	markets.generator = ContentFixture.generator_data(3)
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), markets))

	var generator := content.market_generator
	assert_eq(generator.closed_markets_shown, 3)
	assert_eq(generator.remoteness(1), 5, "1 more than lastport, the most remote hand-made market")
	assert_eq(generator.remoteness(3), 7)
	assert_eq(generator.name_starts, PackedStringArray(["North", "South"]))


func test_reports_bad_generator_values() -> void:
	var errors := _errors(ContentFixture.generator_data(0, {"remoteness_step": 0, "spread": 1.0,
		"favored_colors": 4, "favored_price_factor": 0, "population_base": -1}))

	for part in ["generator.closed_markets_shown must be a positive integer",
			"generator.remoteness_step must be a positive integer",
			"generator.spread must be less than 1",
			"generator.favored_colors (4) cannot be more than the colors available at the start of a run (3)",
			"generator.favored_price_factor must be more than 0",
			"generator.population_base must be a whole number"]:
		assert_true(_has_error(errors, part), "%s in %s" % [part, errors])


func test_reports_a_generator_that_is_not_an_object() -> void:
	assert_true(_has_error(_errors([]), "\"generator\" must be an object"))


func test_reports_bad_name_lists() -> void:
	var errors := _errors(ContentFixture.generator_data(2, {"name_starts": [], "name_ends": ["port", "port"]}))

	assert_true(_has_error(errors, "generator.name_starts must be a list of at least one text"), str(errors))
	assert_true(_has_error(errors, "generator.name_ends has port more than once"), str(errors))


func test_reports_a_generated_name_that_is_a_hand_made_name() -> void:
	var errors := _errors(ContentFixture.generator_data(), ["northport"])

	assert_true(_has_error(errors, "generator: Northport is the name of a hand-made market"), str(errors))


func test_reports_a_hand_made_id_that_looks_generated() -> void:
	var errors := _errors(ContentFixture.generator_data(), ["millbrook", "generated_1"])

	assert_true(_has_error(errors, "generated_1: a hand-made market id cannot start with generated_"), str(errors))


func test_reports_a_generated_market_with_no_capacity() -> void:
	# A capacity of 0.1 for each person, and a population of 5 at most.
	var errors := _errors(ContentFixture.generator_data(2, {"population_base": 5,
		"population_per_remoteness": 0}), ["millbrook"],
		ContentFixture.balance_data(1000, 10, {"capacity_per_population": 0.1, "population_step": 10}))

	assert_true(_has_error(errors, "which gives a capacity of 0"), str(errors))
