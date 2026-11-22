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
		var shown := [color.symbol, color.symbol_mark]
		assert_false(symbols.has(shown), "symbol %s is used twice" % [shown])
		symbols[shown] = true


func test_reads_a_symbol_mark() -> void:
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.tints_and_shades_colors_data(),
		ContentFixture.balance_data(), null, ContentFixture.transport_data(), {"events": []}, null,
		ContentFixture.tints_and_shades_upgrades_data()))

	assert_eq(content.color(&"red").symbol_mark, ColorDef.SymbolMark.NONE, "no mark is the default")
	assert_eq([content.color(&"red_tint").symbol, content.color(&"red_tint").symbol_mark],
		[&"square", ColorDef.SymbolMark.TINT])
	assert_eq([content.color(&"blue_shade").symbol, content.color(&"blue_shade").symbol_mark],
		[&"circle", ColorDef.SymbolMark.SHADE])


func test_a_symbol_with_a_mark_must_be_unique_too() -> void:
	var colors := ContentFixture.colors_data()
	colors.colors.append_array([
		{"id": "pink", "name": "Pink", "symbol": "square", "symbol_mark": "tint", "display": "#ffaaaa", "recipe": {}},
		{"id": "rose", "name": "Rose", "symbol": "square", "symbol_mark": "tint", "display": "#ff8888", "recipe": {}},
		{"id": "rust", "name": "Rust", "symbol": "square", "symbol_mark": "shade", "display": "#882222", "recipe": {}},
		{"id": "teal", "name": "Teal", "symbol": "star", "symbol_mark": "glow", "display": "#00aaaa", "recipe": {}},
	])
	var text := "\n".join(Content.from_data(ContentFixture.data(colors)).errors)

	assert_string_contains(text, "rose: symbol square with the tint mark is already used by pink")
	assert_string_contains(text, "teal: symbol_mark must be one of none, tint, shade, but it is glow")
	assert_false(text.contains("pink: symbol"), "a mark makes a symbol different from the plain one")
	assert_false(text.contains("rust: symbol"), "the tint mark and the shade mark are different")


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


func test_reads_the_warehouse_values() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10,
			{"cost": 45, "space": 60, "unlock_factory_count": 3})))
	assert_eq(content.errors, PackedStringArray())
	assert_true(content.warehouse_balance.build_cost.equals(BigNumber.from_int(45)))
	assert_eq(content.warehouse_balance.space, 60)
	assert_eq(content.warehouse_balance.unlock_factory_count, 3)


func test_reports_bad_warehouse_values() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10,
			{"cost": -1, "space": 0, "unlock_factory_count": 1.5})))
	var text := "\n".join(content.errors)
	for expected in ["warehouse.cost must be a number of at least 0",
			"warehouse.space must be a positive integer",
			"warehouse.unlock_factory_count must be a whole number of at least 0"]:
		assert_string_contains(text, expected)


func test_reports_a_missing_warehouse_section() -> void:
	var balance := ContentFixture.balance_data()
	balance.erase("warehouse")
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors), "warehouse.cost must be a number of at least 0")


func test_reads_the_offline_cap() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10, {"max_time_away_ms": 3_600_000})))
	assert_eq(content.errors, PackedStringArray())
	assert_eq(content.max_offline_ms, 3_600_000)


func test_the_game_data_caps_offline_progress_at_24_hours() -> void:
	assert_eq(Content.load_dir(Content.DEFAULT_DIR).max_offline_ms, 24 * 3_600_000)


func test_reports_a_bad_offline_cap() -> void:
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(1000, 10, {"max_time_away_ms": 0})))
	assert_string_contains("\n".join(content.errors), "offline.max_time_away_ms must be a positive integer")
	var balance := ContentFixture.balance_data()
	balance.offline = "none"
	content = Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors), "balance.json: \"offline\" must be an object")


func test_reads_the_economy_values() -> void:
	var balance := ContentFixture.balance_data(1000, 10, {"build_cost": 25, "starting_money": 120})
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_eq(content.errors, PackedStringArray())
	assert_true(content.factory_balance.build_cost.equals(BigNumber.from_int(25)))
	assert_true(content.starting_money.equals(BigNumber.from_int(120)))


func test_reads_markets_with_a_price_for_each_color() -> void:
	var markets := {"markets": [{"id": "millbrook", "name": "Millbrook", "population": 500, "income": 80,
		"remoteness": 0,
		"prices": {"red": 4, "yellow": 2.5, "blue": 6}}]}
	var content := Content.from_data(ContentFixture.data(
		ContentFixture.colors_data(), ContentFixture.balance_data(), markets))
	assert_eq(content.errors, PackedStringArray())
	assert_eq(content.markets().size(), 1)
	var market := content.market(&"millbrook")
	assert_eq(market.name, "Millbrook")
	assert_eq(market.remoteness, 0)
	assert_true(market.price(&"red").equals(BigNumber.from_int(4)))
	assert_true(market.price(&"yellow").equals(BigNumber.from_float(2.5)))
	assert_eq([market.start_population, market.start_income], [500, 80])
	assert_null(content.market(&"nowhere"))


func test_reads_the_market_balance() -> void:
	var balance := ContentFixture.balance_data(1000, 10, {"period_ms": 30_000,
		"capacity_per_population": 0.25, "reference_income": 40, "investment_cost": 15,
		"investment_cost_growth": 1.5, "population_step": 20, "income_step": 4})
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	var market := content.market_balance
	assert_eq(market.period_ms, 30_000)
	assert_eq(market.capacity(1000), 250)
	assert_eq(market.capacity(1003), 250, "capacity rounds down")
	assert_eq(market.income_factor(40), 1.0)
	assert_eq(market.income_factor(60), 1.5)
	assert_eq([market.population_step, market.income_step], [20, 4])
	assert_eq(market.investment_cost_after(0).format(), "15")
	assert_eq(market.investment_cost_after(1).format(), "23", "22.5 rounds up to a whole number")
	assert_eq([market.period(29_999), market.period(30_000), market.period_end_ms(45_000)], [0, 1, 60_000])


func test_bad_market_balance_and_starts_are_errors() -> void:
	var colors := ContentFixture.colors_data()
	var balance := ContentFixture.balance_data(1000, 10, {"period_ms": 0,
		"capacity_per_population": 0.001, "reference_income": 0, "investment_cost": -1,
		"investment_cost_growth": 0.5, "population_step": 0, "income_step": 1.5})
	var markets := ContentFixture.markets_data(ContentFixture.PRICE, colors, ["millbrook"], 10, 0)
	markets.markets.append({"id": "ashford", "name": "Ashford", "prices": markets.markets[0].prices})
	var content := Content.from_data(ContentFixture.data(colors, balance, markets))
	var text := "\n".join(content.errors)
	for expected in ["market.period_ms must be a positive integer",
			"market.reference_income must be more than 0",
			"market.investment_cost must be a number of at least 0",
			"market.investment_cost_growth must be a number of at least 1",
			"market.population_step must be a positive integer",
			"market.income_step must be a positive integer",
			"millbrook: a population of 10 gives a capacity of 0",
			"millbrook.income must be a positive integer",
			"ashford.population must be a positive integer",
			"ashford.income must be a positive integer"]:
		assert_string_contains(text, expected)


func test_a_population_step_that_adds_no_capacity_is_an_error() -> void:
	var balance := ContentFixture.balance_data(1000, 10, {"capacity_per_population": 0.1, "population_step": 9})
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors),
		"market.population_step times market.capacity_per_population must be at least 1")


func test_a_market_balance_with_no_capacity_per_person_is_an_error() -> void:
	var balance := ContentFixture.balance_data(1000, 10, {"capacity_per_population": 0})
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors), "market.capacity_per_population must be more than 0")


func test_reads_transport_tiers_in_order() -> void:
	var transport := {"automatic_transport_cost": 12.5, "tiers": [
		{"id": "cart", "name": "Cart", "plural_name": "Carts", "max_remoteness": 0, "transit_time_ms": 8000, "shipment_cost": 3},
		{"id": "truck", "name": "Truck", "plural_name": "Trucks", "max_remoteness": 3, "transit_time_ms": 2000, "shipment_cost": 1.5,
			"price": 400, "vehicle_upgrade_cost": 25},
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
	assert_eq([tiers[0].rank, tiers[0].max_remoteness], [0, 0])
	assert_true(tiers[0].price.equals(BigNumber.ZERO), "a run starts with the first tier")
	var truck := content.transport_tier(&"truck")
	assert_eq(truck.transit_time_ms, 2000)
	assert_eq(truck.plural_name, "Trucks")
	assert_eq([truck.rank, truck.max_remoteness], [1, 3])
	assert_true(truck.price.equals(BigNumber.from_int(400)))
	assert_true(truck.vehicle_upgrade_cost.equals(BigNumber.from_int(25)))
	assert_eq(content.automatic_transport_cost.format(), "12.5")


func test_the_game_data_has_a_first_market_and_carts() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var tiers := content.transport_tiers()
	assert_eq(tiers[0].id, &"cart")
	var open := content.markets().filter(func(m: MarketDef) -> bool: return tiers[0].reaches(m.remoteness))
	assert_eq(open.map(func(m: MarketDef) -> StringName: return m.id), [&"millbrook"],
		"a run starts with one market")


func test_the_game_data_has_10_to_15_hand_made_markets_that_tiers_reach() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	assert_eq(content.errors, PackedStringArray())
	assert_between(content.markets().size(), 10, 15)
	# Each tier after carts, up to the one that the most remote hand-made market
	# needs, opens at least one more hand-made market. The tiers after it open
	# generated markets.
	var tiers := content.transport_tiers()
	var most_remote := 0
	for def in content.markets():
		most_remote = maxi(most_remote, def.remoteness)
	for i in range(1, content.tier_for_remoteness(most_remote).rank + 1):
		var opened := content.markets().filter(func(m: MarketDef) -> bool:
			return content.tier_for_remoteness(m.remoteness) == tiers[i])
		assert_gt(opened.size(), 0, "%s opens a market" % tiers[i].id)


func test_the_game_data_has_tiers_after_planes_that_end_in_a_portal() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var tiers := content.transport_tiers()
	var ids := tiers.map(func(t: TransportTier) -> StringName: return t.id)
	assert_eq(ids.slice(0, 5), [&"cart", &"truck", &"train", &"ship", &"plane"])
	assert_gt(ids.size(), 6, "at least one tier between planes and the portal")
	assert_eq(ids[-1], &"portal")
	assert_true(tiers[-1].reaches_any_remoteness)
	assert_true(tiers[-1].reaches(1_000_000_000), "the portal has no remoteness limit")
	for i in range(1, tiers.size() - 1):
		assert_false(tiers[i].reaches_any_remoteness, "%s has a limit" % tiers[i].id)
		assert_gt(tiers[i].max_remoteness, tiers[i - 1].max_remoteness,
			"%s reaches more than %s" % [tiers[i].id, tiers[i - 1].id])


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
		assert_false(content.research_unlocking(id).is_empty(), "research in the data unlocks %s" % id)


const HUES: Array[StringName] = [&"red", &"yellow", &"blue", &"green", &"orange", &"purple",
	&"red_orange", &"yellow_orange", &"yellow_green", &"blue_green", &"blue_purple", &"red_purple"]


func test_the_game_data_has_white_and_black_base_colors_that_prestige_upgrades_unlock() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	for id in [&"white", &"black"]:
		var color := content.color(id)
		assert_not_null(color, "missing color %s" % id)
		if color != null:
			assert_true(color.is_base(), "%s needs no inputs" % id)
			assert_eq(color.unlock, ColorDef.Unlock.PRESTIGE_UPGRADE)
			assert_false(content.prestige_upgrades_unlocking(id).is_empty(), "an upgrade unlocks %s" % id)


func test_each_hue_has_one_tint_and_one_shade_and_brown_has_none() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	# Each recipe with white or black, by the other input.
	var mixes := {&"white": {}, &"black": {}}
	for color in content.colors():
		var recipe := color.recipe
		for base: StringName in mixes:
			if recipe.has(base):
				assert_eq(recipe.size(), 2, "%s has a hue and %s" % [color.id, base])
				assert_true(recipe.values().all(func(n: int) -> bool: return n == 1),
					"%s takes 1 of each input" % color.id)
				for hue: StringName in recipe:
					if hue != base:
						mixes[base][hue] = color
	for base: StringName in mixes:
		assert_eq(mixes[base].size(), 12, "12 colors mix %s with a hue" % base)
		assert_false(mixes[base].has(&"brown"), "brown has nothing with %s" % base)
	for hue in HUES:
		var tint: ColorDef = mixes[&"white"].get(hue)
		var shade: ColorDef = mixes[&"black"].get(hue)
		assert_not_null(tint, "a tint of %s" % hue)
		assert_not_null(shade, "a shade of %s" % hue)
		if tint == null or shade == null:
			continue
		var hue_def := content.color(hue)
		assert_eq([tint.symbol, tint.symbol_mark], [hue_def.symbol, ColorDef.SymbolMark.TINT],
			"the tint of %s has its symbol with the tint mark" % hue)
		assert_eq([shade.symbol, shade.symbol_mark], [hue_def.symbol, ColorDef.SymbolMark.SHADE],
			"the shade of %s has its symbol with the shade mark" % hue)
		for color: ColorDef in [tint, shade]:
			assert_eq(color.unlock, ColorDef.Unlock.PRESTIGE_UPGRADE)
			assert_false(content.prestige_upgrades_unlocking(color.id).is_empty(), "an upgrade unlocks %s" % color.id)


func test_the_upgrade_that_unlocks_white_or_black_unlocks_the_colors_made_with_it() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	for color in content.colors():
		for base: StringName in [&"white", &"black"]:
			if color.recipe.has(base):
				var unlockers := content.prestige_upgrades_unlocking(color.id)
				var base_unlockers := content.prestige_upgrades_unlocking(base)
				assert_eq(unlockers, base_unlockers, "%s unlocks with %s" % [color.id, base])


func test_every_market_of_the_game_data_has_a_price_for_tints_and_shades() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var markets := content.markets()
	for index in range(1, 4):
		markets.append(content.market_generator.generate(21, index))
	for market in markets:
		for hue in HUES:
			for kind in ["tint", "shade"]:
				var id := StringName("%s_%s" % [hue, kind])
				assert_true(market.prices.has(id) and not market.prices[id].is_zero(), "%s pays for %s" % [market.id, id])


func test_reads_research_and_the_lab_cost() -> void:
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data()))

	assert_true(content.lab_build_cost.equals(BigNumber.from_int(ContentFixture.LAB_COST)))
	var ids := content.research().map(func(d: ResearchDef) -> StringName: return d.id)
	assert_eq(ids, [&"earth_tones", &"cool_mixes"])
	var cool := content.research_def(&"cool_mixes")
	assert_eq(cool.name, "Cool mixes")
	assert_eq(cool.cost, {&"green": 3} as Dictionary[StringName, int])
	assert_eq(cool.requires, [&"earth_tones"] as Array[StringName])
	assert_eq(cool.unlock_colors, [&"blue_green"] as Array[StringName])
	assert_eq(content.research_unlocking(&"brown"), [content.research_def(&"earth_tones")] as Array[ResearchDef])


## The errors of content with the mixed colors and the research
## [param entries], with no lab cost when [param lab_cost] is null.
func _research_errors(entries: Array, lab_cost: Variant = 30) -> String:
	var research := {"research": entries}
	if lab_cost != null:
		research.lab_build_cost = lab_cost
	var content := Content.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(), null, ContentFixture.transport_data(), {"events": []}, research))
	return "\n".join(content.errors)


func _valid_research() -> Array:
	return ContentFixture.research_data(ContentFixture.mixed_colors_data()).research


func test_reports_bad_research() -> void:
	var entries := _valid_research()
	assert_eq(_research_errors(entries), "")
	entries.append({"id": "bad", "name": "Bad", "cost": {"magenta": 1, "red": 0},
		"requires": ["later", 3], "unlocks": {"colors": ["green", "teal"], "flight": true}})
	entries.append({"id": "later", "name": "Later", "cost": {}, "unlocks": {}})

	var errors := _research_errors(entries, null)

	for expected in [
		"research.lab_build_cost must be a number of at least 0",
		"bad: cost has magenta, which is not a color",
		"bad: cost of red must be a positive integer",
		"bad: requires later, which must be a research earlier in research.json",
		"bad: each item of research.requires must be a text id",
		"bad: unlocks has flight, but it can have only colors or forecast_accuracy",
		"bad: unlocks green, but the unlock of green is not research",
		"bad: unlocks teal, which is not a color",
		"later: cost must be an object with at least one color",
		"later: unlocks nothing",
	]:
		assert_string_contains(errors, expected)


func test_reports_a_research_color_that_no_research_unlocks() -> void:
	var entries := _valid_research()
	entries.pop_back()

	assert_string_contains(_research_errors(entries),
		"blue_green: no research unlocks it, but its unlock is research")


func test_the_game_data_has_prestige_upgrades() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)

	assert_eq(content.errors, PackedStringArray())
	assert_false(content.prestige_upgrades().is_empty())


func test_reads_prestige_upgrades() -> void:
	var colors := ContentFixture.prestige_colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors))

	var ids := content.prestige_upgrades().map(func(d: PrestigeUpgradeDef) -> StringName: return d.id)
	assert_eq(ids, [&"quick_lines", &"seed_money", &"white_light"])
	var quick := content.prestige_upgrade(&"quick_lines")
	assert_eq([quick.name, quick.price, quick.production_speed], ["Quick lines", 1, 2.0])
	assert_true(quick.starting_money.is_zero())
	assert_eq(quick.unlock_colors, [] as Array[StringName])
	var seed_money := content.prestige_upgrade(&"seed_money")
	assert_eq(seed_money.production_speed, 1.0, "no speed bonus")
	assert_true(seed_money.starting_money.equals(BigNumber.from_int(ContentFixture.SEED_MONEY)))
	assert_eq(content.prestige_upgrade(&"white_light").unlock_colors, [&"white"] as Array[StringName])
	assert_eq(content.color(&"white").unlock, ColorDef.Unlock.PRESTIGE_UPGRADE)
	assert_eq(content.prestige_upgrades_unlocking(&"white"),
		[content.prestige_upgrade(&"white_light")] as Array[PrestigeUpgradeDef])
	assert_null(content.prestige_upgrade(&"magic"))


## The errors of content with the colors of
## [method ContentFixture.prestige_colors_data] and the prestige upgrades
## [param entries].
func _upgrade_errors(entries: Array) -> String:
	var colors := ContentFixture.prestige_colors_data()
	var content := Content.from_data(ContentFixture.data(colors, ContentFixture.balance_data(), null,
		ContentFixture.transport_data(), {"events": []}, null, {"upgrades": entries}))
	return "\n".join(content.errors)


func test_reports_bad_prestige_upgrades() -> void:
	var entries: Array = ContentFixture.prestige_upgrades_data(ContentFixture.prestige_colors_data()).upgrades
	assert_eq(_upgrade_errors(entries), "")
	entries.append({"id": "bad", "name": "Bad", "price": 0,
		"bonuses": {"production_speed": 0.5, "starting_money": -1, "luck": 2},
		"unlocks": {"colors": ["green", "red"], "flight": true}})
	entries.append({"id": "empty", "name": "Empty", "price": 1.5})
	entries.append({"id": "odd", "name": "Odd", "price": 1, "bonuses": [], "unlocks": "white"})

	var errors := _upgrade_errors(entries)

	for expected in [
		"bad.price must be a positive integer",
		"bad: bonuses.production_speed must be a number of more than 1",
		"bad: bonuses.starting_money must be a number of more than 0",
		"bad: bonuses has luck, but it can have only production_speed, starting_money",
		"bad: unlocks has flight, but it can have only colors",
		"bad: unlocks green, which is not a color",
		"bad: unlocks red, but the unlock of red is not prestige_upgrade",
		"empty.price must be a positive integer",
		"empty: gives no bonus and unlocks nothing",
		"odd: bonuses must be an object",
		"odd: unlocks must be an object",
	]:
		assert_string_contains(errors, expected)


func test_reports_a_color_that_no_prestige_upgrade_unlocks() -> void:
	assert_string_contains(_upgrade_errors([]),
		"white: no prestige upgrade unlocks it, but its unlock is prestige_upgrade")


func test_research_cannot_unlock_a_color_of_a_prestige_upgrade() -> void:
	var colors := ContentFixture.prestige_colors_data()
	var research := {"lab_build_cost": 30, "research": [
		{"id": "glow", "name": "Glow", "cost": {"red": 1}, "unlocks": {"colors": ["white"]}}]}
	var content := Content.from_data(ContentFixture.data(colors, ContentFixture.balance_data(), null,
		ContentFixture.transport_data(), {"events": []}, research))

	assert_string_contains("\n".join(content.errors), "glow: unlocks white, but the unlock of white is not research")


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
		{"id": "millbrook", "name": "", "population": 10, "income": 10, "prices": {"red": 0, "pink": 3, "white": 1}},
		{"id": "millbrook", "name": "Again", "population": 10, "income": 10, "prices": {}},
	]}
	var transport := {"automatic_transport_cost": -3,
		"tiers": [{"id": "cart", "name": "", "transit_time_ms": 0, "shipment_cost": -1}, {"id": "jet", "name": "Jet"}]}
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
			"rust: unlock must be one of start, research, prestige_upgrade, but it is magic",
			"rust: recipe needs 3 red, but an input bay holds only 2 (factory.input_bay_capacity)",
			"factory.build_cost must be a number of at least 0",
			"run.starting_money must be a number of at least 0",
			"millbrook: name is missing", "millbrook: price for red must be a positive number",
			"millbrook: price for white, which is not a color",
			"millbrook: no price for teal", "duplicate market id millbrook",
			"cart: name is missing", "cart.transit_time_ms must be a positive integer",
			"cart.shipment_cost must be a number of at least 0",
			"millbrook.remoteness must be a whole number of at least 0",
			"cart.max_remoteness must be a whole number of at least 0",
			"jet.price must be a number of at least 0",
			"jet: plural_name is missing",
			"jet.vehicle_upgrade_cost must be a number of at least 0",
			"transport.automatic_transport_cost must be a number of at least 0"]:
		assert_string_contains(text, expected)


## Transport data with carts that reach [param cart_reach], then trucks that
## reach [param truck_reach]. [param cart_extra] adds keys to the carts.
func _two_tiers(cart_reach: int, truck_reach: int, cart_extra: Dictionary = {}) -> Dictionary:
	var cart := {"id": "cart", "name": "Cart", "plural_name": "Carts", "max_remoteness": cart_reach, "transit_time_ms": 1000,
		"shipment_cost": 1}
	cart.merge(cart_extra)
	return {"automatic_transport_cost": 1, "tiers": [cart,
		{"id": "truck", "name": "Truck", "plural_name": "Trucks", "max_remoteness": truck_reach, "transit_time_ms": 500,
			"shipment_cost": 2, "price": 10, "vehicle_upgrade_cost": 1}]}


func _transport_errors(markets: Dictionary, transport: Dictionary) -> String:
	return "\n".join(Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), markets, transport)).errors)


func test_reports_a_tier_that_reaches_less_than_the_tier_before_it() -> void:
	assert_string_contains(_transport_errors(ContentFixture.markets_data(), _two_tiers(3, 2)),
		"truck: max_remoteness must be more than that of cart, the tier before it")


func test_reports_a_tier_that_reaches_the_same_as_the_tier_before_it() -> void:
	assert_string_contains(_transport_errors(ContentFixture.markets_data(), _two_tiers(2, 2)),
		"truck: max_remoteness must be more than that of cart, the tier before it")


func test_reads_a_last_tier_that_reaches_any_remoteness() -> void:
	var markets := ContentFixture.markets_data(ContentFixture.PRICE, ContentFixture.colors_data(),
		["millbrook", "atlantis"], ContentFixture.POPULATION, ContentFixture.INCOME, [0, 1_000_000])
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), markets, ContentFixture.portal_transport_data()))
	assert_eq(content.errors, PackedStringArray(), "the portal reaches atlantis")
	var portal := content.transport_tier(&"portal")
	assert_true(portal.reaches_any_remoteness)
	assert_true(portal.reaches(1_000_000))
	assert_false(content.transport_tier(&"train").reaches_any_remoteness)
	assert_eq(content.tier_for_remoteness(4).id, &"train")
	assert_eq(content.tier_for_remoteness(5).id, &"portal")


func test_reports_a_tier_after_a_tier_that_reaches_any_remoteness() -> void:
	var transport := _two_tiers(0, 2)
	transport.tiers[0].max_remoteness = "any"
	assert_string_contains(_transport_errors(ContentFixture.markets_data(), transport),
		"truck: comes after cart, which reaches any remoteness, so cart must be the last tier")


func test_reports_a_max_remoteness_that_is_text_but_not_any() -> void:
	var transport := _two_tiers(0, 2)
	transport.tiers[1].max_remoteness = "far"
	assert_string_contains(_transport_errors(ContentFixture.markets_data(), transport),
		"truck.max_remoteness must be a whole number of at least 0 or \"any\"")


func test_reports_a_price_on_the_first_tier() -> void:
	var text := _transport_errors(ContentFixture.markets_data(),
		_two_tiers(0, 2, {"price": 5, "vehicle_upgrade_cost": 1}))
	assert_string_contains(text, "cart: the first tier cannot have a price")
	assert_string_contains(text, "cart: the first tier cannot have a vehicle_upgrade_cost")


func test_reports_a_market_that_no_tier_reaches() -> void:
	var markets := ContentFixture.markets_data(ContentFixture.PRICE, ContentFixture.colors_data(),
		["millbrook", "atlantis"], ContentFixture.POPULATION, ContentFixture.INCOME, [0, 9])
	assert_string_contains(_transport_errors(markets, _two_tiers(0, 2)),
		"atlantis: remoteness 9 is more than any transport tier reaches (truck reaches 2)")


func test_reports_when_the_first_tier_reaches_no_market() -> void:
	var markets := ContentFixture.markets_data(ContentFixture.PRICE, ContentFixture.colors_data(),
		["farpoint"], ContentFixture.POPULATION, ContentFixture.INCOME, [1])
	assert_string_contains(_transport_errors(markets, _two_tiers(0, 2)),
		"the first transport tier (cart) reaches no market")


func test_the_lowest_tier_that_reaches_a_remoteness() -> void:
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), ContentFixture.remote_markets_data()))
	assert_eq(content.tier_for_remoteness(0).id, &"cart")
	assert_eq(content.tier_for_remoteness(1).id, &"truck")
	assert_eq(content.tier_for_remoteness(2).id, &"truck")
	assert_eq(content.tier_for_remoteness(4).id, &"train")
	assert_null(content.tier_for_remoteness(5))


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


func test_reads_the_forecast_balance() -> void:
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10, {"base_accuracy": 0.25, "horizon_ms": 30_000})))

	assert_almost_eq(content.forecast_balance.base_accuracy, 0.25, 1e-9)
	assert_eq(content.forecast_balance.horizon_ms, 30_000)


func test_reports_a_bad_forecast_balance() -> void:
	for case: Array in [
		[{"base_accuracy": -0.1}, "forecast.base_accuracy must be a number of at least 0"],
		[{"base_accuracy": 1.5}, "forecast.base_accuracy must be at most 1"],
		[{"horizon_ms": 0}, "forecast.horizon_ms must be a positive integer"],
	]:
		var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(),
			ContentFixture.balance_data(1000, 10, case[0])))
		assert_string_contains("\n".join(content.errors), case[1])
	var balance := ContentFixture.balance_data()
	balance.forecast = "none"
	var content := Content.from_data(ContentFixture.data(ContentFixture.colors_data(), balance))
	assert_string_contains("\n".join(content.errors), "balance.json: \"forecast\" must be an object")


func test_reads_the_forecast_accuracy_of_research() -> void:
	var entries := _valid_research()
	entries.append({"id": "surveys", "name": "Surveys", "cost": {"red": 1},
		"unlocks": {"forecast_accuracy": 0.3}})

	assert_eq(_research_errors(entries), "")
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(), null, ContentFixture.transport_data(), {"events": []},
		{"lab_build_cost": 30, "research": entries}))
	assert_almost_eq(content.research_def(&"surveys").forecast_accuracy, 0.3, 1e-9)
	assert_eq(content.research_def(&"surveys").unlock_colors, [] as Array[StringName])
	assert_eq(content.research_def(&"earth_tones").forecast_accuracy, 0.0, "no forecast accuracy")


func test_reports_a_bad_forecast_accuracy_of_research() -> void:
	for value: Variant in [0, -0.2, 1.5, "much"]:
		var entries := _valid_research()
		entries.append({"id": "surveys", "name": "Surveys", "cost": {"red": 1},
			"unlocks": {"forecast_accuracy": value}})
		var errors := _research_errors(entries)
		assert_string_contains(errors,
			"surveys: unlocks.forecast_accuracy must be a number of more than 0 and at most 1", str(value))
		assert_string_contains(errors, "surveys: unlocks nothing", str(value))


func test_research_in_the_game_data_makes_the_forecast_more_accurate() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var total := content.forecast_balance.base_accuracy
	for def in content.research():
		total += def.forecast_accuracy

	assert_lt(content.forecast_balance.base_accuracy, 0.25, "with no research, the forecast is nearly random")
	assert_gt(total, content.forecast_balance.base_accuracy + 0.5, "research makes it much more accurate")
	assert_true(total <= 1.0 + 1e-9, "the accuracy that the data gives is at most 1")
