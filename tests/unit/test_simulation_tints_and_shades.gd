extends GutTest
## White, black, tints, and shades: prestige upgrades unlock the white and
## black base factories, and with them the tints (a hue and white) and the
## shades (a hue and black).

const SEED := 21
const TRANSIT_MS := 5000


## One widget per second for each line, 10,000 starting money, shipments that
## take 5 seconds, and the colors and upgrades of
## [method ContentFixture.tints_and_shades_colors_data].
func _content() -> Content:
	var colors := ContentFixture.tints_and_shades_colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": 10_000}), null,
		ContentFixture.transport_data(TRANSIT_MS, 2), {"events": []}, null,
		ContentFixture.tints_and_shades_upgrades_data()))


## A new game in which the player bought [param prisms] prisms.
func _sim(prisms: int = 2) -> Simulation:
	var sim := Simulation.new(_content(), SEED)
	for i in prisms:
		_ok(sim.buy_prism(), "prism %d" % i)
	return sim


## A game that owns both upgrades.
func _unlocked_sim() -> Simulation:
	var sim := _sim(2)
	_ok(sim.buy_prestige_upgrade(&"white_light"), "white light")
	_ok(sim.buy_prestige_upgrade(&"black_ink"), "black ink")
	return sim


func _ok(result: CommandResult, what: String) -> Variant:
	assert_true(result.ok, "%s: %s" % [what, result.message])
	return result.value


func _bay_counts(sim: Simulation, id: int) -> Array:
	return sim.factory(id).input_bays.map(func(bay: InputBayView) -> int: return bay.count)


func test_white_and_black_factories_fail_with_a_reason_before_the_upgrade() -> void:
	var sim := _sim()
	var before := sim.snapshot()

	var white := sim.build_factory(&"white")
	var black := sim.build_factory(&"black")

	assert_eq(white.reason, CommandResult.Reason.COLOR_LOCKED)
	assert_string_contains(white.message, "White light")
	assert_eq(black.reason, CommandResult.Reason.COLOR_LOCKED)
	assert_string_contains(black.message, "Black ink")
	assert_eq(sim.snapshot(), before, "a failed build changes nothing")


func test_tints_and_shades_are_locked_before_the_upgrade() -> void:
	var sim := _sim()

	assert_eq(sim.build_factory(&"red_tint").reason, CommandResult.Reason.COLOR_LOCKED)
	assert_eq(sim.build_factory(&"blue_shade").reason, CommandResult.Reason.COLOR_LOCKED)
	assert_eq(sim.buildable_factory_colors(), [&"red", &"yellow", &"blue"] as Array[StringName])


func test_each_upgrade_unlocks_its_base_color_and_the_colors_made_with_it() -> void:
	var sim := _sim()

	_ok(sim.buy_prestige_upgrade(&"white_light"), "white light")

	assert_true(sim.is_color_unlocked(&"white"))
	assert_true(sim.is_color_unlocked(&"red_tint"))
	assert_false(sim.is_color_unlocked(&"black"), "black needs its own upgrade")
	assert_false(sim.is_color_unlocked(&"blue_shade"))


func test_white_and_black_factories_make_widgets_with_no_inputs() -> void:
	var sim := _unlocked_sim()
	var white: int = _ok(sim.build_factory(&"white"), "white")
	var black: int = _ok(sim.build_factory(&"black"), "black")

	sim.tick(3000)

	for id in [white, black]:
		var view := sim.factory(id)
		assert_eq(view.input_bays.size(), 0, "a base factory has no input bays")
		assert_eq(view.output_bay_count, 3)


func test_a_tint_factory_consumes_one_hue_widget_and_one_white_widget_for_each_widget() -> void:
	var sim := _unlocked_sim()
	var red: int = _ok(sim.build_factory(&"red"), "red")
	var white: int = _ok(sim.build_factory(&"white"), "white")
	var tint: int = _ok(sim.build_factory(&"red_tint"), "tint")
	assert_eq(sim.factory(tint).input_bays.map(func(b: InputBayView) -> Array: return [b.color, b.per_widget]),
		[[&"red", 1], [&"white", 1]])
	sim.tick(4000)
	_ok(sim.start_shipment(_ok(sim.make_factory_link(red, tint), "red link")), "ship red")
	_ok(sim.start_shipment(_ok(sim.make_factory_link(white, tint), "white link")), "ship white")
	sim.tick(TRANSIT_MS)
	assert_eq(_bay_counts(sim, tint), [4, 4], "4 of each arrived")

	sim.tick(3000)

	assert_eq(sim.factory(tint).output_bay_count, 3)
	assert_eq(_bay_counts(sim, tint), [1, 1], "each widget consumed 1 red and 1 white")


func test_a_shade_factory_consumes_one_hue_widget_and_one_black_widget_for_each_widget() -> void:
	var sim := _unlocked_sim()
	var blue: int = _ok(sim.build_factory(&"blue"), "blue")
	var black: int = _ok(sim.build_factory(&"black"), "black")
	var shade: int = _ok(sim.build_factory(&"blue_shade"), "shade")
	sim.tick(2000)
	_ok(sim.start_shipment(_ok(sim.make_factory_link(blue, shade), "blue link")), "ship blue")
	_ok(sim.start_shipment(_ok(sim.make_factory_link(black, shade), "black link")), "ship black")
	sim.tick(TRANSIT_MS)
	assert_eq(_bay_counts(sim, shade), [2, 2])

	sim.tick(5000)

	assert_eq(sim.factory(shade).output_bay_count, 2, "it stops when the inputs are gone")
	assert_eq(_bay_counts(sim, shade), [0, 0])


func test_a_tint_factory_takes_no_black_widgets() -> void:
	var sim := _unlocked_sim()
	var black: int = _ok(sim.build_factory(&"black"), "black")
	var tint: int = _ok(sim.build_factory(&"red_tint"), "tint")

	var result := sim.make_factory_link(black, tint)

	assert_eq(result.reason, CommandResult.Reason.NOT_A_RECIPE_INPUT)


func test_the_unlocks_stay_after_a_prestige() -> void:
	var sim := _sim(3)
	_ok(sim.buy_prestige_upgrade(&"white_light"), "white light")
	_ok(sim.buy_prestige_upgrade(&"black_ink"), "black ink")

	for run in 2:
		_ok(sim.prestige(), "prestige %d" % run)
		assert_eq(sim.buildable_factory_colors(),
			[&"red", &"yellow", &"blue", &"white", &"black", &"red_tint", &"blue_shade"] as Array[StringName],
			"run %d" % run)
		_ok(sim.build_factory(&"white"), "white in run %d" % run)
		_ok(sim.build_factory(&"blue_shade"), "shade in run %d" % run)


func test_a_market_buys_tints_and_shades_at_their_price() -> void:
	var sim := _unlocked_sim()
	var white: int = _ok(sim.build_factory(&"white"), "white")
	sim.tick(2000)
	var link: int = _ok(sim.make_link(white, &"millbrook"), "link")
	var money := sim.money()
	_ok(sim.start_shipment(link), "ship")
	sim.tick(TRANSIT_MS)

	var market := sim.market(&"millbrook")
	assert_true(market.price(&"red_tint").equals(BigNumber.from_int(ContentFixture.PRICE)))
	assert_true(market.price(&"blue_shade").equals(BigNumber.from_int(ContentFixture.PRICE)))
	# 2 white widgets at the price, less the shipment cost of 2.
	assert_true(sim.money().equals(money.add(BigNumber.from_int(2 * ContentFixture.PRICE - 2))),
		"money is %s" % sim.money())
