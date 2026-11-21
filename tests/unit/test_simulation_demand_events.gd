extends GutTest
## Demand events: short, named spikes or crashes in the demand for one or more
## colors. They come from data and start at times that the seeded random
## number generator sets.

const SEED := 21
## With [method _content], each demand event starts this long after the one
## before it, and the first one starts this long after the start of the game.
const INTERVAL_MS := 30_000
## The spike of red and blue in [method ContentFixture.demand_events_data].
const SPIKE_MS := 20_000
const SPIKE_FACTOR := 1.5
## The crash of yellow.
const CRASH_FACTOR := 0.6


## Content with no drift and no saturation, so that demand is only the factor
## of the demand events, and with one event start each [constant INTERVAL_MS].
## [param events] picks the events of [method ContentFixture.demand_events_data].
func _content(events: PackedStringArray = ["red_blue_spike"], overrides: Dictionary = {},
		markets: PackedStringArray = ["millbrook"]) -> Content:
	var values := {"event_interval_min_ms": INTERVAL_MS, "event_interval_max_ms": INTERVAL_MS}
	values.merge(overrides, true)
	var colors := ContentFixture.colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, values),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, markets),
		ContentFixture.transport_data(),
		ContentFixture.demand_events_data(events)))


## Content with two events and starts from 5 s to 10 s apart.
func _random_content(overrides: Dictionary = {}) -> Content:
	var values := {"event_interval_min_ms": 5000, "event_interval_max_ms": 10_000}
	values.merge(overrides, true)
	return _content(["red_blue_spike", "yellow_crash"], values)


func _demand(sim: Simulation, color: StringName, market_id: StringName = &"millbrook") -> float:
	return sim.market(market_id).demand(color)


## The id and start time of each active event.
func _events(sim: Simulation) -> Array:
	return sim.demand_events().map(func(v: DemandEventView) -> Array: return [v.id, v.started_at_ms])


## The id and start time of each event that starts in [param duration_ms],
## from ticks of [param step_ms].
func _event_log(sim: Simulation, duration_ms: int, step_ms: int = 500) -> Array:
	var seen: Array = []
	var elapsed := 0
	while elapsed < duration_ms:
		sim.tick(step_ms)
		elapsed += step_ms
		for event: Array in _events(sim):
			if not seen.has(event):
				seen.append(event)
	return seen


func test_with_no_demand_events_in_the_data_none_occur() -> void:
	var sim := Simulation.new(ContentFixture.make(), SEED)

	sim.tick(3_600_000)

	assert_eq(sim.demand_events().size(), 0)
	assert_eq(_demand(sim, &"red"), 1.0)


func test_an_event_starts_after_its_interval_and_shows_in_the_query() -> void:
	var sim := Simulation.new(_content(), SEED)

	sim.tick(INTERVAL_MS - 1)
	assert_eq(sim.demand_events().size(), 0, "no event before the first start")
	sim.tick(2)

	var events := sim.demand_events()
	assert_eq(events.size(), 1)
	var event := events[0]
	assert_eq(event.id, &"red_blue_spike")
	assert_eq(event.name, "Red and blue spike")
	assert_eq(event.colors, [&"red", &"blue"] as Array[StringName])
	assert_true(event.is_spike())
	assert_eq(event.size, 0.5)
	assert_eq(event.factor, SPIKE_FACTOR)
	assert_eq(event.started_at_ms, INTERVAL_MS)
	assert_eq(event.remaining_ms, SPIKE_MS - 1)


func test_a_spike_raises_the_demand_and_price_of_its_colors_until_it_ends() -> void:
	var sim := Simulation.new(_content(), SEED)

	sim.tick(INTERVAL_MS + 1)

	assert_eq(_demand(sim, &"red"), SPIKE_FACTOR)
	assert_eq(_demand(sim, &"blue"), SPIKE_FACTOR)
	assert_eq(_demand(sim, &"yellow"), 1.0, "a color that is not in the event does not change")
	assert_almost_eq(sim.market(&"millbrook").price(&"red").to_float(), ContentFixture.PRICE * SPIKE_FACTOR, 1e-9)
	sim.tick(SPIKE_MS - 2)
	assert_eq(_demand(sim, &"red"), SPIKE_FACTOR, "the event is active up to its end")
	sim.tick(1)
	assert_eq(_demand(sim, &"red"), 1.0, "the effect ends with the event")
	assert_eq(sim.demand_events().size(), 0)


func test_a_crash_lowers_the_demand_of_its_colors() -> void:
	var sim := Simulation.new(_content(["yellow_crash"]), SEED)

	sim.tick(INTERVAL_MS + 1)

	assert_false(sim.demand_events()[0].is_spike())
	assert_almost_eq(_demand(sim, &"yellow"), CRASH_FACTOR, 1e-12)
	assert_eq(_demand(sim, &"red"), 1.0)


func test_an_event_changes_its_colors_in_every_market() -> void:
	var sim := Simulation.new(_content(["red_blue_spike"], {}, ["millbrook", "ashford"]), SEED)

	sim.tick(INTERVAL_MS + 1)

	assert_eq(_demand(sim, &"red", &"millbrook"), SPIKE_FACTOR)
	assert_eq(_demand(sim, &"red", &"ashford"), SPIKE_FACTOR)


func test_events_that_overlap_multiply_their_factors() -> void:
	# A new spike starts each 15 s, and each one lasts 20 s.
	var sim := Simulation.new(_content(["red_blue_spike"],
		{"event_interval_min_ms": 15_000, "event_interval_max_ms": 15_000}), SEED)

	sim.tick(30_001)

	assert_eq(_events(sim), [[&"red_blue_spike", 15_000], [&"red_blue_spike", 30_000]])
	assert_almost_eq(_demand(sim, &"red"), SPIKE_FACTOR * SPIKE_FACTOR, 1e-12)


func test_a_sale_during_an_event_sells_at_the_event_price() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.build_factory(&"red")
	sim.make_link(1, &"millbrook")
	sim.tick(INTERVAL_MS - ContentFixture.TRANSIT_TIME_MS + 1000)
	var before := sim.money().to_float()
	var count: int = sim.start_shipment(1).value

	sim.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_almost_eq(sim.money().to_float(),
		before - ContentFixture.SHIPMENT_COST + count * ContentFixture.PRICE * SPIKE_FACTOR, 1e-9)


func test_a_sale_that_arrives_as_an_event_starts_sells_at_the_demand_from_before_it() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.build_factory(&"red")
	sim.make_link(1, &"millbrook")
	sim.tick(INTERVAL_MS - ContentFixture.TRANSIT_TIME_MS)
	var before := sim.money().to_float()
	var count: int = sim.start_shipment(1).value

	sim.tick(ContentFixture.TRANSIT_TIME_MS + 1)

	assert_almost_eq(sim.money().to_float(),
		before - ContentFixture.SHIPMENT_COST + count * ContentFixture.PRICE, 1e-9)
	assert_eq(sim.demand_events().size(), 1, "the event started after the sale")


func test_with_a_fixed_seed_the_same_events_occur_at_the_same_times() -> void:
	var first := _event_log(Simulation.new(_random_content(), SEED), 120_000)
	var second := _event_log(Simulation.new(_random_content(), SEED), 120_000)
	var other := _event_log(Simulation.new(_random_content(), SEED + 1), 120_000)

	assert_gt(first.size(), 10, "events occur")
	assert_eq(second, first)
	assert_ne(other, first, "another seed gives other events")
	var ids := first.map(func(e: Array) -> StringName: return e[0])
	assert_true(ids.has(&"red_blue_spike") and ids.has(&"yellow_crash"), "each event can occur")
	for i in range(1, first.size()):
		var gap: int = first[i][1] - first[i - 1][1]
		assert_between(gap, 5000, 10_000, "the time between two starts")


func _game_with_automatic_sales(content: Content) -> Simulation:
	var sim := Simulation.new(content, SEED)
	sim.build_factory(&"red")
	sim.build_factory(&"yellow")
	sim.make_link(1, &"millbrook")
	sim.make_link(2, &"millbrook")
	sim.buy_automatic_transport(1)
	sim.buy_automatic_transport(2)
	return sim


func test_one_long_tick_gives_the_same_state_as_many_short_ticks() -> void:
	var long := _game_with_automatic_sales(_random_content())
	var short := _game_with_automatic_sales(_random_content())

	long.tick(200_000)
	for i in 160:
		short.tick(1250)

	assert_eq(short.snapshot(), long.snapshot())
	assert_eq(_events(short), _events(long))


func test_a_tick_that_ends_at_an_event_start_gives_the_same_state() -> void:
	var whole := _game_with_automatic_sales(_content())
	var split := _game_with_automatic_sales(_content())

	whole.tick(INTERVAL_MS * 3 + 7)
	split.tick(INTERVAL_MS)
	split.tick(INTERVAL_MS * 2 + 7)

	assert_eq(split.snapshot(), whole.snapshot())


func test_events_do_not_change_drift() -> void:
	var drift := {"drift_amplitude": 0.3}
	var with_events := Simulation.new(_random_content(drift), SEED)
	var without := Simulation.new(_content([], drift), SEED)

	for i in 10:
		with_events.tick(7000)
		without.tick(7000)
		var factor := 1.0
		for event in with_events.demand_events():
			if event.colors.has(&"red"):
				factor *= event.factor
		assert_almost_eq(_demand(with_events, &"red"), _demand(without, &"red") * factor, 1e-12)


func test_the_snapshot_holds_the_active_events_and_the_next_start() -> void:
	var sim := Simulation.new(_content(), SEED)

	sim.tick(INTERVAL_MS + 1)

	var snapshot := sim.snapshot()
	assert_eq(snapshot.demand_events, [
		{"event_id": "red_blue_spike", "started_at_ms": INTERVAL_MS, "ends_at_ms": INTERVAL_MS + SPIKE_MS},
	] as Array[Dictionary])
	assert_eq(snapshot.next_demand_event_ms, INTERVAL_MS * 2)
	sim.tick(SPIKE_MS)
	assert_eq(sim.snapshot().demand_events, [] as Array[Dictionary], "a tick forgets events that have ended")
