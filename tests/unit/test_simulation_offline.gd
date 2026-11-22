extends GutTest
## Offline progress: the normal tick for the time away, with manual transport
## off, and a summary of what happened.

const SEED := 11
const MARKET := &"millbrook"


## Content with mixed colors, carts of 5 s that cost 2, drift and saturation.
func _content(starting_money: float = 1000) -> Content:
	var colors := ContentFixture.mixed_colors_data()
	var balance := ContentFixture.balance_data(1000, 10, ContentFixture.demand_overrides().merged(
		{"starting_money": starting_money}))
	return ContentFixture.from_data(ContentFixture.data(colors, balance,
		ContentFixture.markets_data(5, colors)))


## A game with every kind of thing that a tick moves: base and mixed factories
## with more than one line, automatic links to the market and to a mixed
## factory, a manual link with a shipment in transit, and a manual link with
## widgets that wait.
func _busy_game() -> Simulation:
	var sim := Simulation.new(_content(), SEED)
	var yellow: int = sim.build_factory(&"yellow").value
	var blue: int = sim.build_factory(&"blue").value
	var green: int = sim.build_factory(&"green").value
	var red: int = sim.build_factory(&"red").value
	sim.add_production_line(blue)
	for link_id: int in [sim.make_factory_link(yellow, green).value, sim.make_factory_link(blue, green).value,
			sim.make_link(green, MARKET).value]:
		assert_true(sim.buy_automatic_transport(link_id).ok)
		sim.tick(1300)
	var manual: int = sim.make_link(blue, MARKET).value
	sim.make_link(red, MARKET)
	sim.tick(9000)
	assert_true(sim.start_shipment(manual).ok, "a manual shipment in transit")
	sim.tick(700)
	return sim


func test_offline_progress_gives_the_same_state_as_ticks_for_the_same_time() -> void:
	var offline := _busy_game()
	var ticked := _busy_game()
	var duration_ms := 3_600_000 + 4321

	offline.progress_offline(duration_ms)
	var left := duration_ms
	var step := 1
	while left > 0:
		var part := mini(step, left)
		ticked.tick(part)
		left -= part
		step = step * 3 % 9973 + 1

	assert_eq(offline.time_ms(), ticked.time_ms())
	assert_eq(offline.snapshot(), ticked.snapshot())


func test_offline_progress_in_parts_gives_the_same_state_and_summary_as_one_call() -> void:
	var whole := _busy_game()
	var parts := _busy_game()

	var summary := whole.progress_offline(600_000)
	var added := OfflineSummary.new()
	for part_ms: int in [1, 999, 5000, 4000, 89_000, 501_000]:
		added.add(parts.progress_offline(part_ms))

	assert_eq(parts.snapshot(), whole.snapshot())
	assert_eq(added.duration_ms, summary.duration_ms)
	assert_eq(added.widgets_made, summary.widgets_made)
	assert_eq(added.widgets_sold, summary.widgets_sold)
	# The summary sums the money of the parts in another order, so float error
	# can change its last digits. The money of the game is the same.
	assert_almost_eq(added.money_earned.to_float(), summary.money_earned.to_float(),
		summary.money_earned.to_float() * 1e-12)


func test_links_with_manual_transport_start_no_shipments_offline() -> void:
	var sim := Simulation.new(_content(), SEED)
	var factory: int = sim.build_factory(&"red").value
	var link_id: int = sim.make_link(factory, MARKET).value
	var money_before := sim.money()

	var summary := sim.progress_offline(3_600_000)

	assert_eq(sim.link(link_id).shipments_in_transit.size(), 0)
	assert_eq(sim.link(link_id).widgets_per_minute, 0)
	assert_eq(sim.factory(factory).output_bay_count, 10, "the widgets wait in the full output bay")
	assert_true(sim.money().equals(money_before), "no shipment cost money")
	assert_eq(summary.widgets_sold, 0)
	assert_eq(summary.widgets_made, 10)


func test_a_manual_shipment_in_transit_arrives_offline() -> void:
	var sim := Simulation.new(_content(), SEED)
	var factory: int = sim.build_factory(&"red").value
	var link_id: int = sim.make_link(factory, MARKET).value
	sim.tick(4000)
	assert_eq(sim.start_shipment(link_id).value, 4)

	var summary := sim.progress_offline(60_000)

	assert_eq(sim.link(link_id).shipments_in_transit.size(), 0)
	assert_eq(summary.widgets_sold, 4)
	assert_gt(summary.money_earned.to_float(), 0.0)


func test_the_summary_counts_money_earned_widgets_sold_and_widgets_made() -> void:
	var sim := Simulation.new(ContentFixture.make(), SEED)
	var factory: int = sim.build_factory(&"red").value
	var link_id: int = sim.make_link(factory, MARKET).value
	sim.buy_automatic_transport(link_id)
	var money_before := sim.money()

	# Starts at 0 s (no widgets), 5 s, 10 s, 15 s, and 20 s carry 5 widgets
	# each. The four shipments that started by 15 s arrive by 20 s.
	var summary := sim.progress_offline(20_000)

	assert_eq(summary.duration_ms, 20_000)
	assert_eq(summary.widgets_made, 20)
	assert_eq(summary.widgets_sold, 15)
	assert_true(summary.money_earned.equals(BigNumber.from_int(15 * ContentFixture.PRICE)),
		"money earned %s" % summary.money_earned.format())
	var shipment_costs := BigNumber.from_int(3 * ContentFixture.SHIPMENT_COST)
	assert_true(sim.money().equals(money_before.add(summary.money_earned).sub(shipment_costs)),
		"money earned is before the shipment costs")


func test_the_summary_counts_widgets_that_mixed_factories_make_and_consume() -> void:
	var sim := Simulation.new(_content(), SEED)
	var yellow: int = sim.build_factory(&"yellow").value
	var blue: int = sim.build_factory(&"blue").value
	var green: int = sim.build_factory(&"green").value
	sim.buy_automatic_transport(sim.make_factory_link(yellow, green).value)
	sim.buy_automatic_transport(sim.make_factory_link(blue, green).value)
	var before := _widgets_on_hand(sim)

	var summary := sim.progress_offline(30_000)

	# Each green widget consumed one yellow and one blue widget.
	var green_made := sim.factory(green).output_bay_count
	assert_gt(green_made, 0)
	assert_eq(summary.widgets_made, _widgets_on_hand(sim) - before + 2 * green_made)


## Widgets in output bays, input bays, and shipments in transit.
func _widgets_on_hand(sim: Simulation) -> int:
	var count := 0
	for view in sim.factories():
		count += view.output_bay_count
		for bay in view.input_bays:
			count += bay.count + bay.in_transit
	return count


func test_offline_progress_of_no_time_changes_nothing() -> void:
	var sim := _busy_game()
	var before := sim.snapshot()

	var summary := sim.progress_offline(0)

	assert_eq(sim.snapshot(), before)
	assert_eq(summary.duration_ms, 0)
	assert_eq(summary.widgets_made, 0)
	assert_true(summary.money_earned.is_zero())


func test_ticks_after_offline_progress_count_nothing_in_its_summary() -> void:
	var sim := _busy_game()
	var summary := sim.progress_offline(60_000)
	var sold := summary.widgets_sold

	sim.tick(60_000)

	assert_eq(summary.widgets_sold, sold)


# --- The cap on time away -------------------------------------------------------

func test_offline_progress_is_the_time_away_up_to_the_cap() -> void:
	var sim := Simulation.new(_content(), SEED)
	var cap := ContentFixture.MAX_OFFLINE_MS

	assert_eq(sim.max_offline_ms(), cap)
	assert_eq(sim.offline_progress_ms(3_600_000), 3_600_000)
	assert_eq(sim.offline_progress_ms(cap), cap)
	assert_eq(sim.offline_progress_ms(cap + 1), cap)
	assert_eq(sim.offline_progress_ms(30 * cap), cap)
	assert_eq(sim.offline_progress_ms(0), 0)
	assert_eq(sim.offline_progress_ms(-5), 0)


func test_time_away_above_the_cap_gives_no_more_progress() -> void:
	var colors := ContentFixture.colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"max_time_away_ms": 60_000})))
	var capped := Simulation.new(content, SEED)
	var at_cap := Simulation.new(content, SEED)
	for sim: Simulation in [capped, at_cap]:
		var factory: int = sim.build_factory(&"red").value
		sim.buy_automatic_transport(sim.make_link(factory, MARKET).value)

	capped.progress_offline(capped.offline_progress_ms(10 * 60_000))
	at_cap.progress_offline(60_000)

	assert_eq(capped.snapshot(), at_cap.snapshot())
	assert_eq(capped.time_ms(), 60_000)


# --- Every rule of the tick ---------------------------------------------------

## A game that uses each rule that a tick runs: base and mixed factories,
## warehouses, a lab with research, a split, a vehicle on a higher transport
## tier to a remote market, market capacity (small, so that it limits sales),
## a community investment, demand events, drift and saturation, and a manual
## shipment in transit.
func _game_with_every_rule() -> Simulation:
	var colors := ContentFixture.mixed_colors_data()
	var balance := ContentFixture.balance_data(1000, 10, ContentFixture.demand_overrides().merged(
		{"starting_money": 100_000, "capacity_per_population": 0.05}))
	var content := ContentFixture.from_data(ContentFixture.data(colors, balance,
		ContentFixture.remote_markets_data(colors), ContentFixture.transport_data(),
		ContentFixture.demand_events_data()))
	var sim := Simulation.new(content, SEED)
	var red: int = _ok(sim.build_factory(&"red"))
	var yellow: int = _ok(sim.build_factory(&"yellow"))
	var blue: int = _ok(sim.build_factory(&"blue"))
	var green: int = _ok(sim.build_factory(&"green"))
	sim.add_production_line(red)
	var warehouse: int = _ok(sim.build_warehouse(&"red"))
	var lab: int = _ok(sim.build_lab())
	_ok(sim.select_research(&"earth_tones"))
	var to_warehouse: int = _ok(sim.link_factory_to_warehouse(red, warehouse))
	var red_to_market: int = _ok(sim.make_link(red, MARKET))
	var automatic: Array[int] = [to_warehouse, red_to_market,
		_ok(sim.link_warehouse_to_market(warehouse, MARKET)),
		_ok(sim.make_lab_link(yellow, lab)),
		_ok(sim.make_factory_link(yellow, green)),
		_ok(sim.make_factory_link(blue, green))]
	_ok(sim.buy_transport_tier())
	automatic.append(_ok(sim.make_link(green, &"farpoint")))
	for link_id in automatic:
		_ok(sim.buy_automatic_transport(link_id))
		sim.tick(700)
	_ok(sim.set_split({to_warehouse: 60, red_to_market: 40}))
	_ok(sim.upgrade_vehicle(red_to_market))
	_ok(sim.make_community_investment(MARKET, MarketView.Investment.POPULATION))
	var manual: int = _ok(sim.make_link(blue, MARKET))
	sim.tick(9000)
	_ok(sim.start_shipment(manual))
	sim.tick(300)
	return sim


func _ok(result: CommandResult) -> Variant:
	assert_true(result.ok, result.message)
	return result.value


func test_offline_progress_runs_every_rule_of_the_tick_as_ticks_do() -> void:
	var offline := _game_with_every_rule()
	var ticked := _game_with_every_rule()
	var duration_ms := 2 * 3_600_000 + 777

	var summary := offline.progress_offline(duration_ms)
	var left := duration_ms
	var step := 1
	while left > 0:
		var part := mini(step, left)
		ticked.tick(part)
		left -= part
		step = step * 7 % 15_013 + 1

	assert_eq(offline.snapshot(), ticked.snapshot())
	# Each rule did something, so that the comparison covers it.
	assert_eq(offline.research_item(&"earth_tones").total_paid(), 2, "yellow paid for research")
	assert_gt(offline.warehouse(1).count + offline.link(3).widgets_per_minute, 0, "the warehouse moved widgets")
	var split := offline.splits()[0]
	assert_gt(split.shipped[1], 0, "the split shipped to the warehouse")
	assert_gt(split.shipped[2], 0, "the split shipped to the market")
	assert_gt(offline.link(7).widgets_per_minute, 0, "green ships to the remote market by truck")
	assert_gt(summary.widgets_sold, 0)
