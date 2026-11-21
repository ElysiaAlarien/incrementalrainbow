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
	var transport := {"automatic_cost": 12.5, "tiers": [
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
	]}
	var markets := {"markets": [
		{"id": "millbrook", "name": "", "prices": {"red": 0, "pink": 3, "white": 1}},
		{"id": "millbrook", "name": "Again", "prices": {}},
	]}
	var transport := {"automatic_cost": -3,
		"tiers": [{"id": "cart", "name": "", "transit_time_ms": 0, "shipment_cost": -1}]}
	var content := Content.from_data(ContentFixture.data(colors,
		{"factory": {"widget_time_ms": 0}, "run": {"starting_money": -5}}, markets, transport))
	var text := "\n".join(content.errors)
	for expected in ["duplicate color id red", "pink: symbol square is already used",
			"pink: bad display color", "pink: recipe input white is not a color",
			"teal: name is missing", "teal: symbol is missing",
			"teal: recipe count for red must be a positive integer",
			"factory.widget_time_ms must be a positive integer",
			"factory.output_bay_capacity must be a positive integer",
			"factory.build_cost must be a number of at least 0",
			"run.starting_money must be a number of at least 0",
			"millbrook: name is missing", "millbrook: price for red must be a positive number",
			"millbrook: price for white, which is not a color",
			"millbrook: no price for teal", "duplicate market id millbrook",
			"cart: name is missing", "cart.transit_time_ms must be a positive integer",
			"cart.shipment_cost must be a number of at least 0",
			"transport.automatic_cost must be a number of at least 0"]:
		assert_string_contains(text, expected)


func test_reports_empty_market_and_transport_lists() -> void:
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), {"markets": []}, {"tiers": []}))
	var text := "\n".join(content.errors)
	assert_string_contains(text, "markets.json: there must be at least one market")
	assert_string_contains(text, "transport.json: there must be at least one transport tier")


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
