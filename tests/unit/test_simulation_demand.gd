extends GutTest
## Demand: each market has its own demand for each color, and demand sets the
## price there. Drift moves demand slowly, and the player's own recent sales
## saturate it.

const SEED := 11
const MARKETS: PackedStringArray = ["millbrook", "ashford"]
const DRIFT_AMPLITUDE := 0.3
## A red factory with one line makes this many widgets before its first
## shipment in [method _game_with_red_link].
const SHIPMENT := 10


## Content with two markets, drift, and saturation. [param overrides] replaces
## balance values.
func _content(overrides: Dictionary = {}) -> Content:
	var values := ContentFixture.demand_overrides()
	values.merge(overrides, true)
	var colors := ContentFixture.colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 50, values),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS)))


## A game with a red factory, linked to millbrook, that has made [constant SHIPMENT]
## widgets. Returns the simulation; the link id is 1.
func _game_with_red_link(content: Content = _content(), rng_seed: int = SEED) -> Simulation:
	var sim := Simulation.new(content, rng_seed)
	sim.build_factory(&"red")
	sim.make_link(1, &"millbrook")
	sim.tick(SHIPMENT * 1000)
	return sim


func _demand(sim: Simulation, market_id: StringName, color: StringName) -> float:
	return sim.market(market_id).demand(color)


## Every demand, by market and color.
func _demands(sim: Simulation) -> Dictionary:
	var all := {}
	for view in sim.markets():
		all[view.id] = view.demands.duplicate()
	return all


func test_each_market_gives_a_demand_and_a_price_for_each_color() -> void:
	var sim := Simulation.new(_content(), SEED)

	var views := sim.markets()

	assert_eq(views.size(), 2)
	for view in views:
		for color in [&"red", &"yellow", &"blue"]:
			var demand := view.demand(color)
			assert_between(demand, 1.0 - DRIFT_AMPLITUDE, 1.0 + DRIFT_AMPLITUDE, "%s %s" % [view.id, color])
			assert_almost_eq(view.price(color).to_float(), ContentFixture.PRICE * demand, 1e-9,
				"the price is the base price times demand")
		assert_true(sim.market(view.id).price(&"red").equals(view.price(&"red")))
	assert_true(is_nan(views[0].demand(&"magenta")), "no demand for an unknown color")
	assert_null(views[0].price(&"magenta"))


func test_each_market_and_color_has_its_own_drift() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.tick(25_000)

	var seen := {}
	for view in sim.markets():
		for color in view.demands:
			seen[view.demands[color]] = true

	assert_eq(seen.size(), 6, "six markets and colors give six demands")


func test_with_a_fixed_seed_drift_gives_the_same_demand_each_time() -> void:
	var first := Simulation.new(_content(), SEED)
	var second := Simulation.new(_content(), SEED)

	for duration in [0, 1234, 9000, 60_000, 3_600_000]:
		first.tick(duration)
		second.tick(duration)
		assert_eq(_demands(first), _demands(second), "at %d ms" % first.time_ms())


func test_another_seed_gives_other_drift() -> void:
	var first := Simulation.new(_content(), SEED)
	var second := Simulation.new(_content(), SEED + 1)

	assert_ne(_demands(first), _demands(second))


func test_demand_drifts_over_ticks_with_no_sales() -> void:
	var sim := Simulation.new(_content(), SEED)
	var seen := {}
	var lowest := INF
	var highest := -INF

	for i in 100:
		var demand := _demand(sim, &"millbrook", &"red")
		seen[demand] = true
		lowest = minf(lowest, demand)
		highest = maxf(highest, demand)
		assert_between(demand, 1.0 - DRIFT_AMPLITUDE, 1.0 + DRIFT_AMPLITUDE)
		sim.tick(3000)

	assert_gt(seen.size(), 90, "demand changes over time")
	assert_gt(highest - lowest, DRIFT_AMPLITUDE / 2.0, "demand moves across its range")


func test_drift_is_slow_and_continuous() -> void:
	var sim := Simulation.new(_content(), SEED)

	for i in 300:
		var before := _demand(sim, &"ashford", &"blue")
		sim.tick(100)
		var after := _demand(sim, &"ashford", &"blue")
		# The steepest step of a smooth knot-to-knot move over 1% of a period.
		assert_lt(absf(after - before), 0.01, "at %d ms" % sim.time_ms())


func test_with_no_drift_amplitude_demand_stays_at_1() -> void:
	var sim := Simulation.new(_content({"drift_amplitude": 0.0}), SEED)

	for i in 10:
		sim.tick(7777)
		assert_eq(_demand(sim, &"millbrook", &"yellow"), 1.0)


func test_a_sale_lowers_the_demand_and_price_of_that_color_in_that_market() -> void:
	var sim := _game_with_red_link()
	var control := _game_with_red_link()
	sim.start_shipment(1)

	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	control.tick(ContentFixture.TRANSIT_TIME_MS)

	var sold := sim.market(&"millbrook")
	var unsold := control.market(&"millbrook")
	assert_lt(sold.demand(&"red"), unsold.demand(&"red"))
	assert_true(sold.price(&"red").is_less_than(unsold.price(&"red")), "the price goes down")
	# 10 recent widgets, which is the half count of the fixture, halve demand.
	assert_almost_eq(sold.demand(&"red"), unsold.demand(&"red") / 2.0, 1e-12)


func test_more_widgets_saturate_more() -> void:
	var small := _game_with_red_link()
	var large := _game_with_red_link()
	small.tick(1)
	small.start_shipment(1)
	large.tick(1)
	large.start_shipment(1)
	large.tick(5000)
	large.start_shipment(1)

	small.tick(5000 + ContentFixture.TRANSIT_TIME_MS)
	large.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_eq(small.time_ms(), large.time_ms())
	assert_lt(_demand(large, &"millbrook", &"red"), _demand(small, &"millbrook", &"red"))


func test_a_shipment_sells_at_the_price_when_it_arrives() -> void:
	var sim := _game_with_red_link()
	var control := _game_with_red_link()
	sim.start_shipment(1)
	var money := sim.money()

	# One long tick past the arrival: the sale uses the price at the arrival.
	sim.tick(ContentFixture.TRANSIT_TIME_MS + 7000)
	control.tick(ContentFixture.TRANSIT_TIME_MS)

	var price := control.market(&"millbrook").price(&"red")
	assert_true(sim.money().equals(money.add(price.mul(BigNumber.from_int(SHIPMENT)))),
		"got %s" % sim.money())


func test_saturation_recovers_over_ticks_with_no_sales() -> void:
	var sim := _game_with_red_link()
	var control := _game_with_red_link()
	sim.start_shipment(1)
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	control.tick(ContentFixture.TRANSIT_TIME_MS)
	var ratio := _demand(sim, &"millbrook", &"red") / _demand(control, &"millbrook", &"red")

	for i in SHIPMENT - 1:
		sim.tick(1000)
		control.tick(1000)
		var next := _demand(sim, &"millbrook", &"red") / _demand(control, &"millbrook", &"red")
		assert_gt(next, ratio, "saturation recovers at %d ms" % sim.time_ms())
		assert_lt(next, 1.0)
		ratio = next

	# Each widget takes 1 s to recover.
	sim.tick(1000)
	control.tick(1000)
	assert_eq(_demand(sim, &"millbrook", &"red"), _demand(control, &"millbrook", &"red"),
		"saturation has recovered fully")
	assert_eq(sim.snapshot().saturation, [], "recovered saturation leaves no state")


func test_a_sale_does_not_saturate_other_colors_or_other_markets() -> void:
	var sim := _game_with_red_link()
	var control := _game_with_red_link()
	sim.start_shipment(1)

	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	control.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_lt(_demand(sim, &"millbrook", &"red"), _demand(control, &"millbrook", &"red"))
	var others := _demands(control)
	var got := _demands(sim)
	others.millbrook.erase(&"red")
	got.millbrook.erase(&"red")
	assert_eq(got, others)


func test_with_no_saturation_a_sale_keeps_demand() -> void:
	var content := _content({"saturation_ms_per_widget": 0})
	var sim := _game_with_red_link(content)
	var control := _game_with_red_link(content)
	sim.start_shipment(1)

	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	control.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_eq(_demands(sim), _demands(control))
	assert_eq(sim.snapshot().saturation, [])


## Two factories that ship to both markets often, so that shipments arrive in
## the middle of long ticks and saturation recovers and comes back.
func _play_with_sales(sim: Simulation, ticks: Array) -> void:
	sim.build_factory(&"red")
	sim.build_factory(&"blue")
	sim.make_link(1, &"millbrook")
	sim.make_link(1, &"ashford")
	sim.make_link(2, &"millbrook")
	for step in 12:
		for duration: int in ticks:
			sim.tick(duration)
		sim.start_shipment(1 + step % 3)


func test_one_long_tick_gives_the_same_demand_as_many_short_ticks() -> void:
	var one := Simulation.new(_content(), SEED)
	var many := Simulation.new(_content(), SEED)

	_play_with_sales(one, [3700])
	_play_with_sales(many, [100, 1200, 2400])
	one.tick(4321)
	for i in 4321:
		many.tick(1)

	assert_eq(one.time_ms(), many.time_ms())
	assert_ne(one.snapshot().saturation, [], "the test has saturation at the end")
	assert_eq(one.snapshot(), many.snapshot())
	assert_eq(_demands(one), _demands(many))
	assert_true(one.money().equals(many.money()))
