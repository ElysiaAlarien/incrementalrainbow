extends GutTest
## Generated markets: after the hand-made markets, a generator makes new
## markets, so that the game has no end. The fixture markets are millbrook
## (remoteness 0), farpoint (2), and lastport (4). Carts reach 0, trucks 2,
## and trains 4. The game shows 2 closed markets.

const SEED := 12


func _content(closed_markets_shown: int = 2) -> Content:
	var colors := ContentFixture.mixed_colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, ContentFixture.demand_overrides().merged(
			{"starting_money": 1000})),
		ContentFixture.generated_markets_data(colors, closed_markets_shown)))


func _ids(sim: Simulation) -> Array[StringName]:
	var ids: Array[StringName] = []
	for view in sim.markets():
		ids.append(view.id)
	return ids


## The markets as plain data, for comparisons.
func _describe(views: Array[MarketView]) -> Array:
	return views.map(func(v: MarketView) -> Array:
		var prices := {}
		for color in v.prices:
			prices[color] = v.price(color).to_data()
		return [v.id, v.name, v.remoteness, v.population, v.income, prices])


func _generated(sim: Simulation) -> Array[MarketView]:
	return sim.markets().filter(func(v: MarketView) -> bool: return String(v.id).begins_with("generated_"))


func test_a_new_game_has_only_hand_made_markets_while_enough_are_closed() -> void:
	var sim := Simulation.new(_content(), SEED)

	assert_eq(_ids(sim), [&"millbrook", &"farpoint", &"lastport"] as Array[StringName])


func test_after_the_last_hand_made_market_the_next_market_comes_from_the_generator() -> void:
	var sim := Simulation.new(_content(), SEED)

	assert_true(sim.buy_transport_tier().ok)
	assert_eq(_ids(sim), [&"millbrook", &"farpoint", &"lastport", &"generated_1"] as Array[StringName],
		"with trucks, only lastport is closed, so the game makes one more")
	assert_true(sim.buy_transport_tier().ok)
	assert_eq(_ids(sim), [&"millbrook", &"farpoint", &"lastport", &"generated_1", &"generated_2"] as Array[StringName],
		"with trains, all hand-made markets are open")
	var closed := sim.markets().filter(func(v: MarketView) -> bool: return not v.is_open)
	assert_eq(closed.size(), 2)


func test_with_a_fixed_seed_the_generator_gives_the_same_markets_each_time() -> void:
	var a := Simulation.new(_content(5), SEED)
	var b := Simulation.new(_content(5), SEED)
	var other := Simulation.new(_content(5), SEED + 1)

	assert_eq(_generated(a).size(), 3)
	assert_eq(_describe(_generated(a)), _describe(_generated(b)))
	assert_ne(_describe(_generated(a)), _describe(_generated(other)), "another seed gives other markets")


func test_each_generated_market_has_a_remoteness_a_population_an_income_and_a_demand_for_each_color() -> void:
	var content := _content(5)
	var sim := Simulation.new(content, SEED)
	sim.tick(25_000)

	for view in _generated(sim):
		assert_gt(view.remoteness, 4, "%s is more remote than the hand-made markets" % view.id)
		assert_gt(view.population, 0)
		assert_gt(view.income, 0)
		assert_gt(view.capacity, 0)
		assert_false(view.name.is_empty())
		for color in content.colors():
			var demand := view.demand(color.id)
			assert_true(is_finite(demand) and demand > 0.0, "%s has a demand for %s" % [view.id, color.id])
			assert_true(view.price(color.id).is_greater_than(BigNumber.ZERO), "%s has a price for %s" % [view.id, color.id])


func test_population_and_income_come_from_the_rules() -> void:
	# Market n has remoteness 4 + n. Population is 1000 + 100 for each step,
	# income 100 + 10, each within 20%.
	var sim := Simulation.new(_content(5), SEED)

	for view in _generated(sim):
		assert_between(view.population, roundi((1000 + 100 * view.remoteness) * 0.8),
			roundi((1000 + 100 * view.remoteness) * 1.2))
		assert_between(view.income, roundi((100 + 10 * view.remoteness) * 0.8),
			roundi((100 + 10 * view.remoteness) * 1.2))


func test_one_color_of_each_generated_market_has_a_higher_base_price() -> void:
	# The fixture hand-made markets pay 5 for each color, and one color of a
	# generated market has double that. Drift is off here, so the price is the
	# base price times the factor from income.
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(), ContentFixture.generated_markets_data(ContentFixture.mixed_colors_data(), 5)))
	var sim := Simulation.new(content, SEED)

	for view in _generated(sim):
		var factor := float(view.income) / ContentFixture.INCOME
		var favored := 0
		for color in view.prices:
			var base := view.price(color).to_float() / factor
			assert_true(is_equal_approx(base, 5.0) or is_equal_approx(base, 10.0), "%s %s: %f" % [view.id, color, base])
			if is_equal_approx(base, 10.0):
				favored += 1
				assert_eq(content.color(color).unlock, ColorDef.Unlock.START,
					"%s favors %s, which is available at the start of a run" % [view.id, color])
		assert_eq(favored, 1, "%s has one favored color" % view.id)


func test_colors_with_another_unlock_do_not_change_the_favored_colors() -> void:
	var colors := ContentFixture.colors_data()
	var plain := ContentFixture.from_data(ContentFixture.data(colors, ContentFixture.balance_data(),
		ContentFixture.generated_markets_data(colors, 5)))
	# A research color between the start colors, and a prestige color at the end.
	var more := ContentFixture.colors_data()
	more.colors.insert(1, {"id": "brown", "name": "Brown", "symbol": "star", "display": "#8b5a33",
		"recipe": {"red": 1, "yellow": 1, "blue": 1}, "unlock": "research"})
	more.colors.append({"id": "white", "name": "White", "symbol": "octagon", "display": "#f4f4f4",
		"recipe": {}, "unlock": "prestige_upgrade"})
	var with_more := ContentFixture.from_data(ContentFixture.data(more, ContentFixture.balance_data(),
		ContentFixture.generated_markets_data(more, 5)))

	for index in range(1, 30):
		var a := plain.market_generator.generate(0xC0FFEE, index)
		var b := with_more.market_generator.generate(0xC0FFEE, index)
		for color in [&"red", &"yellow", &"blue"]:
			assert_true(a.price(color).equals(b.price(color)), "market %d, %s" % [index, color])


func test_remoteness_goes_up_with_each_generated_market() -> void:
	var sim := Simulation.new(_content(6), SEED)

	var last := 4
	for view in _generated(sim):
		assert_gt(view.remoteness, last, view.id)
		last = view.remoteness


func test_a_tier_that_reaches_a_generated_market_opens_it_for_sales() -> void:
	# With only millbrook (remoteness 0), the first generated markets have
	# remoteness 1 and 2, so trucks reach them.
	var markets := ContentFixture.markets_data()
	markets.generator = ContentFixture.generator_data(1)
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(), markets))
	var sim := Simulation.new(content, SEED)
	assert_false(sim.market(&"generated_1").is_open)
	assert_true(sim.buy_transport_tier().ok)
	assert_true(sim.market(&"generated_1").is_open)
	assert_true(sim.market(&"generated_2").is_open)
	assert_false(sim.market(&"generated_3").is_open, "the game shows 1 closed market")
	assert_true(sim.build_factory(&"red").ok)
	sim.tick(3000)
	var link := sim.make_link(1, &"generated_2")
	assert_true(link.ok, link.message)
	assert_true(sim.start_shipment(1).ok)
	var before := sim.money()

	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)

	assert_true(sim.money().is_greater_than(before))
	assert_gt(sim.market(&"generated_2").capacity_used, 0)


func test_no_transport_tier_reaches_a_market_past_the_highest_tier() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.buy_transport_tier()
	sim.buy_transport_tier()
	assert_true(sim.build_factory(&"red").ok)

	var view := sim.market(&"generated_1")
	assert_false(view.is_open)
	assert_eq(view.needed_tier, &"")
	var result := sim.make_link(1, &"generated_1")
	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.MARKET_TOO_REMOTE)
	assert_string_contains(result.message, "no transport tier reaches it yet")


func test_a_community_investment_in_a_generated_market_grows_it() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.buy_transport_tier()
	var before := sim.market(&"generated_1").population

	var result := sim.make_community_investment(&"generated_1", MarketView.Investment.POPULATION)

	assert_true(result.ok, result.message)
	assert_eq(sim.market(&"generated_1").population, before + ContentFixture.POPULATION_STEP)


func test_a_prestige_makes_the_markets_of_a_new_game() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.buy_transport_tier()
	sim.buy_transport_tier()
	assert_true(sim.buy_prism().ok)

	assert_true(sim.prestige().ok)

	assert_eq(_ids(sim), [&"millbrook", &"farpoint", &"lastport"] as Array[StringName])
	sim.buy_transport_tier()
	assert_eq(_generated(sim).size(), 1)
	# The new run has the generated markets of a fresh game with its drift key.
	var fresh := _content().market_generator.generate(sim.snapshot().drift_key, 1)
	var view := sim.market(&"generated_1")
	assert_eq([view.name, view.remoteness, view.population, view.income],
		[fresh.name, fresh.remoteness, fresh.start_population, fresh.start_income])


func test_the_generator_can_make_markets_with_no_limit() -> void:
	var generator := _content().market_generator
	var last_remoteness := 4
	var names := {}
	for index in range(1, 2001):
		var def := generator.generate(77, index)
		assert_gt(def.remoteness, last_remoteness)
		last_remoteness = def.remoteness
		names[def.name] = true
	# Two starts and two ends give four names, then the same four with 2, and
	# so on, so each name is new.
	assert_eq(names.size(), 2000, "each generated market has its own name")
	var far := generator.generate(77, 1_000_000)
	assert_eq(far.id, &"generated_1000000")
	assert_eq(far.remoteness, 4 + 1_000_000)
	assert_gt(far.start_population, 0)
	assert_gt(far.start_income, 0)
	for color in _content().colors():
		assert_true(far.price(color.id).is_greater_than(BigNumber.ZERO))


func test_the_game_data_has_a_market_generator() -> void:
	# The most remote hand-made market of the game has remoteness 8.
	var content := Content.load_dir(Content.DEFAULT_DIR)
	assert_eq(content.errors, PackedStringArray())
	var generator := content.market_generator
	assert_not_null(generator)
	assert_eq(generator.generate(1, 1).remoteness, 9)
	var sim := Simulation.new(content, SEED)
	assert_eq(sim.markets().size(), content.markets().size(),
		"a new game has enough closed hand-made markets")


func test_with_the_game_data_each_tier_after_planes_opens_generated_markets() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	# A save gives the game enough money to buy every tier.
	var save: Dictionary = JSON.parse_string(SaveCodec.encode(Simulation.new(content, SEED), 0))
	save.state.money = BigNumber.from_int(1_000_000_000).to_data()
	var sim := SaveCodec.decode(content, JSON.stringify(save)).simulation
	var open_count := func() -> int:
		return sim.markets().filter(func(v: MarketView) -> bool: return v.is_open).size()
	while sim.transport_tier().id != &"plane":
		assert_true(sim.buy_transport_tier().ok)
	assert_eq(open_count.call(), content.markets().size(), "planes reach only the hand-made markets")

	while sim.next_transport_tier() != null:
		var before: int = open_count.call()
		var tier := sim.next_transport_tier().id
		assert_true(sim.buy_transport_tier().ok)
		assert_gt(open_count.call(), before, "%s opens generated markets" % tier)

	assert_eq(sim.transport_tier().id, &"portal")
	assert_eq(open_count.call(), sim.markets().size(), "the portal opens every market")


func test_the_forecast_has_each_color_of_each_generated_market() -> void:
	var content := _content(5)
	var sim := Simulation.new(content, SEED)

	var forecast := sim.forecast(30_000)

	assert_gt(_generated(sim).size(), 0)
	for view in _generated(sim):
		for color in content.colors():
			var demand := forecast.demand(view.id, color.id)
			assert_true(is_finite(demand) and demand > 0.0, "a forecast for %s in %s" % [color.id, view.id])
