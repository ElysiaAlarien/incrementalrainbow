extends GutTest
## Content (colors, symbols, recipes, and balance values) comes from data files.


func test_the_game_data_loads_with_no_errors() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	assert_eq(content.errors, PackedStringArray(), "errors in res://data")


func test_the_game_data_has_the_three_primary_colors_as_base_colors() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	for id in [&"red", &"yellow", &"blue"]:
		var color := content.color(id)
		assert_not_null(color, "missing color %s" % id)
		if color != null:
			assert_true(color.is_base(), "%s needs no inputs" % id)
			assert_ne(color.symbol, &"", "%s has a symbol" % id)


func test_each_color_has_its_own_symbol() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var symbols := {}
	for color in content.colors():
		assert_false(symbols.has(color.symbol), "symbol %s is used twice" % color.symbol)
		symbols[color.symbol] = true


func test_reads_balance_values_as_ints() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(2500, 4)))
	assert_eq(content.errors, PackedStringArray())
	assert_eq(content.factory_balance.widget_time_ms, 2500)
	assert_eq(typeof(content.factory_balance.widget_time_ms), TYPE_INT)
	assert_eq(content.factory_balance.output_bay_capacity, 4)


func test_reads_production_line_cost_and_starting_money() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10,
			{"starting_money": 250, "production_line_cost": 12, "production_line_cost_growth": 1.5})))
	assert_eq(content.errors, PackedStringArray())
	assert_true(content.starting_money.equals(BigNumber.from_int(250)))
	assert_true(content.factory_balance.production_line_cost.equals(BigNumber.from_int(12)))
	assert_eq(content.factory_balance.production_line_cost_growth, 1.5)


func test_reports_bad_production_line_cost_and_starting_money() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10,
			{"starting_money": -1, "production_line_cost": -5, "production_line_cost_growth": 0.5})))
	var text := "\n".join(content.errors)
	for expected in ["run.starting_money must be a number of at least 0",
			"factory.production_line_cost must be a number of at least 0",
			"factory.production_line_cost_growth must be a number of at least 1"]:
		assert_string_contains(text, expected)


func test_reads_the_prism_price_values() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10,
			{"first_price": 30, "price_growth": 1.5})))
	assert_eq(content.errors, PackedStringArray())
	assert_true(content.prism_balance.first_price.equals(BigNumber.from_int(30)))
	assert_eq(content.prism_balance.price_growth, 1.5)


func test_reports_bad_prism_price_values() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10,
			{"first_price": 0, "price_growth": 0.5})))
	var text := "\n".join(content.errors)
	assert_string_contains(text, "prism.first_price must be a number of at least 1")
	assert_string_contains(text, "prism.price_growth must be a number of at least 1")


func test_reports_prism_prices_that_would_not_go_up() -> void:
	# 3, 3.3, 3.63 all give a whole-number price of 4 after the first.
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10,
			{"first_price": 3, "price_growth": 1.1})))
	assert_string_contains("\n".join(content.errors),
		"prism.price_growth is too low: first_price * (price_growth - 1) must be at least 1")


func test_reports_a_missing_prism_section() -> void:
	var balance := ContentFixture.balance_data()
	balance.prism = "none"
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors), "balance.json: \"prism\" must be an object")


func test_reads_the_economy_values() -> void:
	var balance := ContentFixture.balance_data(1000, 10, {"build_cost": 25, "starting_money": 120})
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_eq(content.errors, PackedStringArray())
	assert_true(content.factory_balance.build_cost.equals(BigNumber.from_int(25)))
	assert_true(content.starting_money.equals(BigNumber.from_int(120)))


func test_reads_markets_with_a_price_for_each_color() -> void:
	var markets := {"markets": [{"id": "millbrook", "name": "Millbrook",
		"prices": {"red": 4, "yellow": 2.5, "blue": 6}}]}
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(), markets))
	assert_eq(content.errors, PackedStringArray())
	assert_eq(content.markets().size(), 1)
	var market := content.market(&"millbrook")
	assert_eq(market.name, "Millbrook")
	assert_true(market.price(&"red").equals(BigNumber.from_int(4)))
	assert_true(market.price(&"yellow").equals(BigNumber.from_float(2.5)))
	assert_null(content.market(&"nowhere"))


func test_reads_transport_tiers_in_order() -> void:
	var transport := {"automatic_transport_cost": 12.5, "tiers": [
		{"id": "cart", "name": "Cart", "transit_time_ms": 8000, "shipment_cost": 3},
		{"id": "truck", "name": "Truck", "transit_time_ms": 2000, "shipment_cost": 1.5},
	]}
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), ContentFixture.markets_data(), transport))
	assert_eq(content.errors, PackedStringArray())
	var tiers := content.transport_tiers()
	assert_eq(tiers.size(), 2)
	assert_eq(tiers[0].id, &"cart")
	assert_eq(tiers[0].name, "Cart")
	assert_eq(tiers[0].transit_time_ms, 8000)
	assert_true(tiers[0].shipment_cost.equals(BigNumber.from_int(3)))
	assert_eq(content.transport_tier(&"truck").transit_time_ms, 2000)
	assert_eq(content.automatic_transport_cost.format(), "12.5")


func test_the_game_data_has_a_first_market_and_carts() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	assert_eq(content.markets().size(), 1, "a run starts with one market")
	assert_eq(content.transport_tiers()[0].id, &"cart")


func test_the_game_data_has_a_recipe_for_each_mixed_color() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var recipes := {
		&"green": {&"yellow": 1, &"blue": 1},
		&"orange": {&"red": 1, &"yellow": 1},
		&"purple": {&"red": 1, &"blue": 1},
		&"red_orange": {&"red": 1, &"orange": 1},
		&"yellow_orange": {&"yellow": 1, &"orange": 1},
		&"yellow_green": {&"yellow": 1, &"green": 1},
		&"blue_green": {&"blue": 1, &"green": 1},
		&"blue_purple": {&"blue": 1, &"purple": 1},
		&"red_purple": {&"red": 1, &"purple": 1},
		&"brown": {&"red": 1, &"yellow": 1, &"blue": 1},
	}
	for id: StringName in recipes:
		var color := content.color(id)
		assert_not_null(color, "missing color %s" % id)
		if color != null:
			assert_eq(color.recipe, recipes[id], "recipe of %s" % id)


func test_research_unlocks_the_tertiary_colors_and_brown() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	for id in [&"red", &"yellow", &"blue", &"green", &"orange", &"purple"]:
		assert_eq(content.color(id).unlock, ColorDef.Unlock.START, "%s is there from the start" % id)
	for id in [&"red_orange", &"yellow_orange", &"yellow_green", &"blue_green", &"blue_purple",
			&"red_purple", &"brown"]:
		assert_eq(content.color(id).unlock, ColorDef.Unlock.RESEARCH, "%s needs research" % id)


func test_reads_a_recipe() -> void:
	var colors := ContentFixture.colors_data()
	colors.colors.append({"id": "green", "name": "Green", "symbol": "diamond",
		"display": "#3a9a4a", "recipe": {"yellow": 1, "blue": 1}})
	var content := Content.from_data(ContentFixture.data(colors))
	assert_eq(content.errors, PackedStringArray())
	assert_false(content.color(&"green").is_base())
	assert_eq(content.color(&"green").recipe, {&"yellow": 1, &"blue": 1})


func test_reports_bad_data() -> void:
	var colors := {"colors": [
		{"id": "red", "name": "Red", "symbol": "square", "display": "#ff0000", "recipe": {}},
		{"id": "red", "name": "Red again", "symbol": "circle", "display": "#ff0000", "recipe": {}},
		{"id": "pink", "name": "Pink", "symbol": "square", "display": "not a color", "recipe": {"white": 1}},
		{"id": "teal", "name": "", "symbol": "", "display": "#00aaaa", "recipe": {"red": 0.5}},
		{"id": "rust", "name": "Rust", "symbol": "star", "display": "#aa5500",
			"recipe": {"rust": 1, "red": 3}, "unlock": "magic"},
	]}
	var markets := {"markets": [
		{"id": "millbrook", "name": "", "prices": {"red": 0, "pink": 3, "white": 1}},
		{"id": "millbrook", "name": "Again", "prices": {}},
	]}
	var transport := {"automatic_transport_cost": -3,
		"tiers": [{"id": "cart", "name": "", "transit_time_ms": 0, "shipment_cost": -1}]}
	var content := Content.from_data(ContentFixture.data(colors,
		{"factory": {"widget_time_ms": 0, "input_bay_capacity": 2}, "run": {"starting_money": -5}}, markets, transport))
	var text := "\n".join(content.errors)
	for expected in ["duplicate color id red", "pink: symbol square is already used",
			"pink: bad display color", "pink: recipe input white is not a color",
			"teal: name is missing", "teal: symbol is missing",
			"teal: recipe count for red must be a positive integer",
			"factory.widget_time_ms must be a positive integer",
			"factory.output_bay_capacity must be a positive integer",
			"rust: a recipe cannot use its own color",
			"rust: unlock must be one of start, research, but it is magic",
			"rust: recipe needs 3 red, but an input bay holds only 2 (factory.input_bay_capacity)",
			"factory.build_cost must be a number of at least 0",
			"run.starting_money must be a number of at least 0",
			"millbrook: name is missing", "millbrook: price for red must be a positive number",
			"millbrook: price for white, which is not a color",
			"millbrook: no price for teal", "duplicate market id millbrook",
			"cart: name is missing", "cart.transit_time_ms must be a positive integer",
			"cart.shipment_cost must be a number of at least 0",
			"transport.automatic_transport_cost must be a number of at least 0"]:
		assert_string_contains(text, expected)


func test_reports_empty_market_and_transport_lists() -> void:
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), {"markets": []}, {"tiers": []}))
	var text := "\n".join(content.errors)
	assert_string_contains(text, "markets.json: there must be at least one market")
	assert_string_contains(text, "transport.json: there must be at least one transport tier")


func test_reads_demand_balance_values() -> void:
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10, {"drift_period_ms": 45_000.0, "drift_amplitude": 0.25,
			"saturation_ms_per_widget": 1500.0, "saturation_half_widgets": 12.5})))
	var demand := content.demand_balance
	assert_eq(demand.drift_period_ms, 45_000)
	assert_eq(demand.drift_amplitude, 0.25)
	assert_eq(demand.saturation_ms_per_widget, 1500)
	assert_eq(demand.saturation_half_widgets, 12.5)


func test_zero_turns_drift_and_saturation_off() -> void:
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10, {"drift_amplitude": 0.0, "saturation_ms_per_widget": 0.0})))
	assert_eq(content.errors, PackedStringArray())


func test_reports_bad_demand_balance_values() -> void:
	var bad := {"drift_period_ms": 0, "drift_amplitude": 1.0,
		"saturation_ms_per_widget": 2.5, "saturation_half_widgets": 0}
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10, bad)))
	var text := "\n".join(content.errors)
	for expected in ["demand.drift_period_ms must be a positive integer",
			"demand.drift_amplitude must be less than 1",
			"demand.saturation_ms_per_widget must be a whole number of at least 0",
			"demand.saturation_half_widgets must be a number of more than 0"]:
		assert_string_contains(text, expected)
	bad = {"drift_amplitude": -0.1, "saturation_ms_per_widget": -1}
	text = "\n".join(Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10, bad))).errors)
	assert_string_contains(text, "demand.drift_amplitude must be a number of at least 0")
	assert_string_contains(text, "demand.saturation_ms_per_widget must be a whole number of at least 0")


func test_reports_a_missing_demand_section() -> void:
	var balance := ContentFixture.balance_data()
	balance.erase("demand")
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors), "demand.drift_period_ms must be a positive integer")
	balance.demand = []
	content = Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors), "balance.json: \"demand\" must be an object")


func test_reports_a_missing_data_file() -> void:
	var content := Content.load_dir("res://no_such_dir")
	assert_eq(content.errors.size(), Content.FILES.size())
	assert_string_contains(content.errors[0], "cannot read res://no_such_dir/colors.json")


func test_content_cannot_be_changed_through_what_it_returns() -> void:
	var content := ContentFixture.make()
	content.color(&"red").recipe[&"blue"] = 1
	content.colors().clear()
	content.errors.append("not an error")
	content.markets().clear()
	content.market(&"millbrook").prices.erase(&"red")
	assert_true(content.color(&"red").is_base())
	assert_eq(content.colors().size(), 3)
	assert_eq(content.errors, PackedStringArray())
	assert_eq(content.markets().size(), 1)
	assert_not_null(content.market(&"millbrook").price(&"red"))


# --- Demand events --------------------------------------------------------------

func _events_content(events: Array, overrides: Dictionary = {}) -> Content:
	var colors := ContentFixture.colors_data()
	return Content.from_data(ContentFixture.data(colors, ContentFixture.balance_data(1000, 10, overrides),
		null, ContentFixture.transport_data(), {"events": events}))


func test_reads_demand_events_in_order() -> void:
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10, {"event_interval_min_ms": 2000, "event_interval_max_ms": 9000}),
		null, ContentFixture.transport_data(), ContentFixture.demand_events_data()))

	assert_eq(content.errors, PackedStringArray())
	var events := content.demand_events()
	assert_eq(events.map(func(d: DemandEventDef) -> StringName: return d.id), [&"red_blue_spike", &"yellow_crash"])
	var spike := content.demand_event(&"red_blue_spike")
	assert_eq(spike.name, "Red and blue spike")
	assert_eq(spike.colors, [&"red", &"blue"] as Array[StringName])
	assert_eq(spike.direction, DemandEventDef.Direction.SPIKE)
	assert_eq(spike.size, 0.5)
	assert_eq(spike.duration_ms, 20_000)
	assert_eq(spike.factor(), 1.5)
	var crash := content.demand_event(&"yellow_crash")
	assert_eq(crash.direction, DemandEventDef.Direction.CRASH)
	assert_almost_eq(crash.factor(), 0.6, 1e-12)
	assert_null(content.demand_event(&"no_such_event"))
	assert_eq(content.demand_balance.event_interval_min_ms, 2000)
	assert_eq(content.demand_balance.event_interval_max_ms, 9000)


func test_an_empty_list_of_demand_events_is_valid() -> void:
	var content := _events_content([])

	assert_eq(content.errors, PackedStringArray())
	assert_eq(content.demand_events().size(), 0)


func test_the_game_data_has_demand_events_of_both_directions() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var directions := {}
	for def in content.demand_events():
		directions[def.direction] = true
	assert_eq(directions.size(), 2)


func test_reports_bad_demand_events() -> void:
	var content := _events_content([
		{"id": "a", "name": "A", "colors": [], "direction": "spike", "size": 0.5, "duration_ms": 1000},
		{"id": "b", "name": "B", "colors": ["red", "magenta", "red"], "direction": "boom", "size": 0.5, "duration_ms": 1000},
		{"id": "c", "name": "C", "colors": ["red"], "direction": "crash", "size": 1, "duration_ms": 1000},
		{"id": "d", "name": "D", "colors": ["red"], "direction": "spike", "size": 0, "duration_ms": 0},
		{"id": "d", "name": "D again", "colors": ["red"], "direction": "spike", "size": 1, "duration_ms": 1},
		{"name": "No id", "colors": ["red"], "direction": "spike", "size": 1, "duration_ms": 1},
	])

	var text := "\n".join(content.errors)
	for expected in ["a: colors must be a list of at least one color id",
			"b: magenta is not a color",
			"b: color red is in the list more than once",
			"b: direction must be one of spike, crash, but it is boom",
			"c: the size of a crash must be less than 1, so that demand stays above 0",
			"d: size must be a number of more than 0",
			"d.duration_ms must be a positive integer",
			"duplicate demand event id d",
			"demand_events.json: a demand event has no id"]:
		assert_string_contains(text, expected)
	content = Content.from_data(ContentFixture.data(ContentFixture.colors_data(), ContentFixture.balance_data(),
		null, ContentFixture.transport_data(), {}))
	assert_string_contains("\n".join(content.errors), "demand_events.json: \"events\" must be a list")


func test_reports_bad_demand_event_intervals() -> void:
	var content := _events_content([], {"event_interval_min_ms": 0, "event_interval_max_ms": 1.5})
	var text := "\n".join(content.errors)
	assert_string_contains(text, "demand.event_interval_min_ms must be a positive integer")
	assert_string_contains(text, "demand.event_interval_max_ms must be a positive integer")

	content = _events_content([], {"event_interval_min_ms": 5000, "event_interval_max_ms": 4000})
	assert_string_contains("\n".join(content.errors),
		"demand.event_interval_max_ms must be at least demand.event_interval_min_ms")

	content = _events_content([], {"event_interval_min_ms": 1, "event_interval_max_ms": 1 + (1 << 31)})
	assert_string_contains("\n".join(content.errors),
		"demand.event_interval_max_ms can be at most 2147483647 more than demand.event_interval_min_ms")
