extends GutTest
## The forecast: the player's view of the future demand of each color in each
## market. It starts nearly random, and forecast research makes it more
## accurate.

const SEED := 17
const MARKETS: PackedStringArray = ["millbrook", "ashford"]
const COLORS: Array[StringName] = [&"red", &"yellow", &"blue"]
const DRIFT_AMPLITUDE := 0.3
const AHEAD_MS := 7000


## Content with two markets and drift (a knot each 10 s, up to 30%), and no
## saturation, demand events, or research. [param overrides] replaces balance
## values.
func _content(overrides: Dictionary = {}) -> Content:
	var values := {"drift_amplitude": DRIFT_AMPLITUDE}
	values.merge(overrides, true)
	var colors := ContentFixture.colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, values),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS)))


func test_a_query_gives_the_forecast_of_each_color_in_each_market_and_its_accuracy() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.tick(3000)

	var forecast := sim.forecast(AHEAD_MS)

	assert_eq(forecast.at_ms, 10_000, "the time of the forecast is now plus the time ahead")
	assert_eq(forecast.ahead_ms, AHEAD_MS)
	assert_almost_eq(forecast.accuracy, ContentFixture.FORECAST_BASE_ACCURACY, 1e-9)
	assert_almost_eq(sim.forecast_accuracy(), ContentFixture.FORECAST_BASE_ACCURACY, 1e-9)
	for market_id in MARKETS:
		for color in COLORS:
			assert_between(forecast.demand(market_id, color), 1.0 - DRIFT_AMPLITUDE, 1.0 + DRIFT_AMPLITUDE,
				"%s %s" % [market_id, color])
	assert_true(is_nan(forecast.demand(&"millbrook", &"magenta")), "no forecast for an unknown color")
	assert_true(is_nan(forecast.demand(&"nowhere", &"red")), "no forecast for an unknown market")
	assert_eq(sim.forecast_horizon_ms(), ContentFixture.FORECAST_HORIZON_MS)


## Like [method _content], with labs and forecast research that each cost 2
## red widgets: "market_surveys" adds 0.5 accuracy, and then "trend_analysis"
## adds 0.4, which makes the forecast exact (0.1 + 0.5 + 0.4).
func _content_with_research(overrides: Dictionary = {}) -> Content:
	var values := {"drift_amplitude": DRIFT_AMPLITUDE, "starting_money": 10_000}
	values.merge(overrides, true)
	var colors := ContentFixture.colors_data()
	var research := {"lab_build_cost": ContentFixture.LAB_COST, "research": [
		{"id": "market_surveys", "name": "Market surveys", "cost": {"red": 2},
			"unlocks": {"forecast_accuracy": 0.5}},
		{"id": "trend_analysis", "name": "Trend analysis", "requires": ["market_surveys"],
			"cost": {"red": 2}, "unlocks": {"forecast_accuracy": 0.4}},
	]}
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, values),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS),
		ContentFixture.transport_data(), {"events": []}, research))


## A game of [param content] with a lab and a red factory linked to it.
## Returns the link id.
func _game_with_lab(sim: Simulation) -> int:
	assert_true(sim.build_lab().ok)
	assert_true(sim.build_factory(&"red").ok)
	var result := sim.make_lab_link(1, 1)
	assert_true(result.ok, result.message)
	return result.value


## Selects [param research_id] and ships red widgets to the lab until it is
## complete.
func _complete(sim: Simulation, link_id: int, research_id: StringName) -> void:
	assert_true(sim.select_research(research_id).ok)
	sim.tick(2000)
	assert_true(sim.start_shipment(link_id).ok)
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	assert_eq(sim.research_item(research_id).status, ResearchView.Status.COMPLETE)


## The mean of |forecast - real demand| over each market and color, for
## forecasts of each of [param count] times, each [param step_ms] apart. Each
## forecast is [constant AHEAD_MS] ahead, and the real demand is the demand
## after a tick to that time.
func _mean_error(sim: Simulation, count: int, step_ms: int) -> float:
	var total := 0.0
	var samples := 0
	for i in count:
		var forecast := sim.forecast(AHEAD_MS)
		sim.tick(AHEAD_MS)
		for view in sim.markets():
			for color in COLORS:
				total += absf(forecast.demand(view.id, color) - view.demand(color))
				samples += 1
		sim.tick(step_ms)
	return total / samples


func test_with_no_forecast_research_the_forecast_is_nearly_random() -> void:
	var sim := Simulation.new(_content(), SEED)

	var error := _mean_error(sim, 100, 3001)

	# Two independent values from 0.7 to 1.3 differ by about 0.2 on average.
	assert_gt(error, 0.12, "the forecast is far from the real demand")


func test_forecast_research_makes_the_forecast_closer_to_the_real_future_demand() -> void:
	var before := Simulation.new(_content_with_research(), SEED)
	var after := Simulation.new(_content_with_research(), SEED)
	var link := _game_with_lab(after)
	_game_with_lab(before)
	_complete(after, link, &"market_surveys")
	before.tick(after.time_ms())

	assert_almost_eq(after.forecast_accuracy(), 0.6, 1e-9)
	assert_almost_eq(before.forecast_accuracy(), ContentFixture.FORECAST_BASE_ACCURACY, 1e-9)
	var error_before := _mean_error(before, 60, 2003)
	var error_after := _mean_error(after, 60, 2003)
	assert_lt(error_after, error_before * 0.5, "the error is less than half as large")


func test_research_that_makes_the_forecast_exact_gives_the_real_future_demand() -> void:
	var sim := Simulation.new(_content_with_research(), SEED)
	var link := _game_with_lab(sim)
	_complete(sim, link, &"market_surveys")
	_complete(sim, link, &"trend_analysis")

	assert_almost_eq(sim.forecast_accuracy(), 1.0, 1e-9)
	var forecast := sim.forecast(AHEAD_MS)
	sim.tick(AHEAD_MS)
	for view in sim.markets():
		for color in COLORS:
			assert_almost_eq(forecast.demand(view.id, color), view.demand(color), 1e-9,
				"%s %s" % [view.id, color])


func test_the_forecast_accuracy_is_never_more_than_one() -> void:
	var sim := Simulation.new(_content_with_research({"base_accuracy": 0.5}), SEED)
	var link := _game_with_lab(sim)
	_complete(sim, link, &"market_surveys")
	_complete(sim, link, &"trend_analysis")

	assert_almost_eq(sim.forecast_accuracy(), 1.0, 1e-9)


## Every forecast of [param sim], by market and color, [param ahead_ms] ahead.
func _forecasts(sim: Simulation, ahead_ms: int = AHEAD_MS) -> Dictionary:
	return sim.forecast(ahead_ms).demands.duplicate(true)


func test_with_a_fixed_seed_the_forecast_is_the_same_each_time() -> void:
	var first := Simulation.new(_content(), SEED)
	var second := Simulation.new(_content(), SEED)
	var other := Simulation.new(_content(), SEED + 1)

	for duration in [0, 1234, 9000, 60_000]:
		first.tick(duration)
		second.tick(duration)
		other.tick(duration)
		assert_eq(_forecasts(first), _forecasts(second), "same seed after %d ms" % duration)
		assert_eq(_forecasts(first), _forecasts(first), "a second query gives the same forecast")
		assert_ne(_forecasts(first), _forecasts(other), "another seed gives another forecast")


func test_asking_for_a_forecast_does_not_change_the_future_demand() -> void:
	# Drift, saturation, and demand events, with sales.
	var colors := ContentFixture.colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, ContentFixture.demand_overrides()),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS),
		ContentFixture.transport_data(), ContentFixture.demand_events_data()))
	var asked := Simulation.new(content, SEED)
	var not_asked := Simulation.new(content, SEED)
	for sim in [asked, not_asked]:
		sim.build_factory(&"red")
		sim.make_link(1, &"millbrook")
		sim.buy_automatic_transport(1)

	for i in 40:
		for ahead_ms in [0, 500, AHEAD_MS, 120_000]:
			asked.forecast(ahead_ms)
		asked.tick(2500)
		not_asked.tick(2500)

	assert_gt(asked.time_ms(), 0)
	assert_eq(asked.snapshot(), not_asked.snapshot())
	for view in asked.markets():
		assert_eq(view.demands, not_asked.market(view.id).demands, view.id)


func test_the_forecast_has_saturation_and_demand_events_that_have_started() -> void:
	# The exact forecast, with saturation and one long red and blue spike.
	var colors := ContentFixture.colors_data()
	var balance := ContentFixture.balance_data(1000, 10, {"drift_amplitude": DRIFT_AMPLITUDE,
		"saturation_ms_per_widget": 1000, "base_accuracy": 1.0,
		"event_interval_min_ms": 3000, "event_interval_max_ms": 3000})
	var events := ContentFixture.demand_events_data(["red_blue_spike"])
	var content := ContentFixture.from_data(ContentFixture.data(colors, balance,
		ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS),
		ContentFixture.transport_data(), events))
	var sim := Simulation.new(content, SEED)
	sim.build_factory(&"red")
	sim.make_link(1, &"millbrook")
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	sim.start_shipment(1)
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	assert_eq(sim.demand_events().size(), 3, "spikes started at 3 s, 6 s, and 9 s, and all are active")
	assert_eq(sim.market(&"millbrook").capacity_used, 5, "red widgets sold in millbrook, so it is saturated")

	# The next event starts at 12 s, after this forecast, which is for 11 s.
	var forecast := sim.forecast(1000)
	sim.tick(1000)

	for view in sim.markets():
		for color in COLORS:
			assert_almost_eq(forecast.demand(view.id, color), view.demand(color), 1e-9,
				"%s %s" % [view.id, color])


func test_the_forecast_does_not_know_demand_events_that_have_not_started() -> void:
	var colors := ContentFixture.colors_data()
	var balance := ContentFixture.balance_data(1000, 10, {"drift_amplitude": DRIFT_AMPLITUDE,
		"base_accuracy": 1.0, "event_interval_min_ms": 3000, "event_interval_max_ms": 3000})
	var content := ContentFixture.from_data(ContentFixture.data(colors, balance,
		ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS),
		ContentFixture.transport_data(), ContentFixture.demand_events_data(["red_blue_spike"])))
	var sim := Simulation.new(content, SEED)

	var forecast := sim.forecast(4000)
	sim.tick(4000)

	assert_eq(sim.demand_events().size(), 1, "an event started at 3 s")
	var real := sim.market(&"millbrook").demand(&"red")
	assert_almost_eq(forecast.demand(&"millbrook", &"red") * 1.5, real, 1e-9,
		"the forecast is the demand without the spike of 0.5")


func test_saving_and_loading_keeps_the_forecast_and_its_accuracy() -> void:
	var sim := Simulation.new(_content_with_research(), SEED)
	var link := _game_with_lab(sim)
	_complete(sim, link, &"market_surveys")
	sim.tick(1234)

	var result := SaveCodec.decode(_content_with_research(), SaveCodec.encode(sim, 1_700_000_000_000))

	assert_true(result.ok, result.message)
	assert_almost_eq(result.simulation.forecast_accuracy(), 0.6, 1e-9)
	assert_eq(_forecasts(result.simulation), _forecasts(sim))
	assert_eq(_forecasts(result.simulation, 50_000), _forecasts(sim, 50_000))
