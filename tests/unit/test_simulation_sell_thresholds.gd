extends GutTest
## Sell thresholds: a warehouse with a sell threshold holds its color from a
## market while the demand there is below the threshold, and sends it again
## when demand goes up. See ADR-0016.

const SEED := 15
const MARKET := &"millbrook"
const OTHER_MARKET := &"ashford"
const TRANSIT_MS := 5000
## With [method _sim], one sale of 10 widgets halves demand (to 50%), and the
## saturation recovers at one widget each second.
const SALE := 10


## Two markets, mixed colors, one widget per second for each line, output bays
## of 10, carts of 5 s that cost 2, much money, no drift, and saturation in
## which 10 recent widgets halve demand. Warehouses hold [param space] widgets.
func _sim(space: int = 20) -> Simulation:
	var colors := ContentFixture.mixed_colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": 10_000, "space": space,
			"saturation_ms_per_widget": 1000, "saturation_half_widgets": SALE}),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, [MARKET, OTHER_MARKET]),
		ContentFixture.transport_data(TRANSIT_MS, 2)))
	return Simulation.new(content, SEED)


func _ok(result: CommandResult, what: String) -> Variant:
	assert_true(result.ok, "%s: %s" % [what, result.message])
	return result.value


func _assert_fails(sim: Simulation, result: CommandResult, reason: CommandResult.Reason,
		message_part: String) -> void:
	var before := sim.snapshot()
	assert_false(result.ok, "the command fails")
	assert_eq(result.reason, reason, result.message)
	assert_string_contains(result.message, message_part)
	assert_eq(sim.snapshot(), before, "the state does not change")


func _demand_percent(sim: Simulation, market_id: StringName = MARKET) -> int:
	return roundi(sim.market(market_id).demand(&"red") * 100.0)


## At time 20 s: a red factory (1), a red warehouse (1) with 10 widgets on the
## way that arrive at 25 s, a manual link into it (1), and a manual link out of
## it to millbrook (2). Millbrook just sold 10 red widgets from the warehouse,
## so its red demand is 50%, and it is back at 100% at 30 s.
func _saturated_game(space: int = 20) -> Simulation:
	var sim := _sim(space)
	_ok(sim.build_factory(&"red"), "factory")
	_ok(sim.build_warehouse(&"red"), "warehouse")
	sim.tick(10_000)
	var into: int = _ok(sim.link_factory_to_warehouse(1, 1), "link in")
	var out: int = _ok(sim.link_warehouse_to_market(1, MARKET), "link out")
	assert_eq(_ok(sim.start_shipment(into), "ship in"), 10)
	sim.tick(TRANSIT_MS)
	assert_eq(_ok(sim.start_shipment(out), "ship out"), 10)
	sim.tick(TRANSIT_MS)
	assert_eq(_ok(sim.start_shipment(into), "ship in again"), 10)
	assert_eq(_demand_percent(sim), 50, "the sale halves demand")
	return sim


# --- The command and the query -------------------------------------------------

func test_a_new_warehouse_has_no_sell_threshold_and_does_not_hold() -> void:
	var sim := _sim()
	_ok(sim.build_warehouse(&"red"), "warehouse")

	var view := sim.warehouse(1)

	assert_eq(view.sell_threshold, WarehouseView.NO_SELL_THRESHOLD)
	assert_false(view.holds())
	assert_eq(view.held_market_ids, [] as Array[StringName])


func test_the_player_sets_and_clears_a_sell_threshold() -> void:
	var sim := _sim()
	_ok(sim.build_warehouse(&"red"), "warehouse")

	_ok(sim.set_sell_threshold(1, 80), "set")
	assert_eq(sim.warehouse(1).sell_threshold, 80)

	_ok(sim.set_sell_threshold(1, 250), "a threshold can be above 100%, as demand can")
	assert_eq(sim.warehouse(1).sell_threshold, 250)

	_ok(sim.clear_sell_threshold(1), "clear")
	assert_eq(sim.warehouse(1).sell_threshold, WarehouseView.NO_SELL_THRESHOLD)


func test_clearing_no_sell_threshold_fails() -> void:
	var sim := _sim()
	_ok(sim.build_warehouse(&"red"), "warehouse")
	_assert_fails(sim, sim.clear_sell_threshold(1), CommandResult.Reason.NO_SELL_THRESHOLD,
		"Red warehouse #1 has no sell threshold")
	_assert_fails(sim, sim.clear_sell_threshold(2), CommandResult.Reason.UNKNOWN_WAREHOUSE,
		"There is no warehouse #2")


func test_a_sell_threshold_on_an_unknown_warehouse_fails() -> void:
	var sim := _sim()
	_assert_fails(sim, sim.set_sell_threshold(3, 80), CommandResult.Reason.UNKNOWN_WAREHOUSE,
		"There is no warehouse #3")


func test_a_sell_threshold_below_1_percent_fails() -> void:
	var sim := _sim()
	_ok(sim.build_warehouse(&"red"), "warehouse")
	for percent in [0, -1, -2]:
		_assert_fails(sim, sim.set_sell_threshold(1, percent), CommandResult.Reason.BAD_SELL_THRESHOLD,
			"A sell threshold must be a whole percentage of at least 1%%, but it is %d%%" % percent)


# --- Hold and send -------------------------------------------------------------

func test_a_warehouse_holds_while_demand_is_below_the_threshold_and_sends_when_it_goes_up() -> void:
	var sim := _saturated_game()
	_ok(sim.set_sell_threshold(1, 80), "threshold")
	_ok(sim.buy_automatic_transport(2), "automatic out")

	# The automatic starts at 20 s and 25 s find demand at 50% and 67%. The
	# widgets arrive in the warehouse at 25 s, before the second start.
	sim.tick(TRANSIT_MS + 1)
	assert_eq(_demand_percent(sim), 67)
	assert_eq(sim.link(2).automatic, LinkView.Automatic.HELD)
	assert_eq(sim.link(2).shipments_in_transit.size(), 0, "the warehouse sends nothing")
	assert_eq(sim.warehouse(1).count, 10, "the warehouse keeps its widgets")
	assert_true(sim.warehouse(1).holds())
	assert_eq(sim.warehouse(1).held_market_ids, [MARKET] as Array[StringName])

	# The next start is at 30 s, when demand is back at 100%.
	sim.tick(TRANSIT_MS)
	assert_eq(_demand_percent(sim), 100)
	assert_eq(sim.link(2).automatic, LinkView.Automatic.SHIPPED)
	assert_eq(sim.link(2).shipments_in_transit[0].count, 10, "the warehouse sends again")
	assert_eq(sim.warehouse(1).count, 0)
	assert_false(sim.warehouse(1).holds())


func test_the_hold_shows_now_before_the_next_automatic_start() -> void:
	var sim := _saturated_game()
	_ok(sim.buy_automatic_transport(2), "automatic out")
	assert_false(sim.warehouse(1).holds(), "no threshold, no hold")

	_ok(sim.set_sell_threshold(1, 80), "threshold")

	assert_eq(sim.link(2).automatic, LinkView.Automatic.READY, "no automatic start yet")
	assert_true(sim.warehouse(1).holds(), "the query reads the demand now")
	sim.tick(8000)
	assert_eq(_demand_percent(sim), 83)
	assert_false(sim.warehouse(1).holds())


func test_a_manual_link_never_holds() -> void:
	var sim := _saturated_game()

	_ok(sim.set_sell_threshold(1, 80), "threshold")

	assert_eq(_demand_percent(sim), 50)
	assert_false(sim.warehouse(1).holds(), "only automatic starts hold")


func test_demand_equal_to_the_threshold_does_not_hold() -> void:
	var sim := _saturated_game()
	_ok(sim.set_sell_threshold(1, 100), "threshold")
	sim.tick(TRANSIT_MS * 2)
	assert_eq(_demand_percent(sim), 100)

	assert_false(sim.warehouse(1).holds())
	_ok(sim.buy_automatic_transport(2), "automatic out")
	sim.tick(1)
	assert_eq(sim.link(2).automatic, LinkView.Automatic.SHIPPED)


func test_the_hold_compares_the_demand_that_the_screen_shows() -> void:
	var sim := _saturated_game()
	# 7.5 s after the sale, 2.5 widgets of saturation are left: demand is
	# 80.0%. Just before it, demand shows as 80%, but it is below 80.0%.
	sim.tick(7499)
	assert_eq(_demand_percent(sim), 80)
	assert_lt(sim.market(MARKET).demand(&"red"), 0.8)
	_ok(sim.buy_automatic_transport(2), "automatic out")

	_ok(sim.set_sell_threshold(1, 80), "threshold")

	assert_false(sim.warehouse(1).holds(), "80% is not below 80%")


func test_a_shipment_by_hand_is_outside_the_hold() -> void:
	var sim := _saturated_game()
	_ok(sim.buy_automatic_transport(2), "automatic out")
	_ok(sim.set_sell_threshold(1, 80), "threshold")
	sim.tick(TRANSIT_MS)
	assert_true(sim.warehouse(1).holds())
	assert_eq(sim.link(2).automatic, LinkView.Automatic.HELD)

	assert_eq(_ok(sim.start_shipment(2), "ship by hand"), 10, "the player ships on purpose")


func test_a_threshold_holds_only_from_markets_with_low_demand() -> void:
	var sim := _saturated_game()
	var to_other: int = _ok(sim.link_warehouse_to_market(1, OTHER_MARKET), "link to ashford")
	_ok(sim.set_sell_threshold(1, 80), "threshold")
	_ok(sim.buy_automatic_transport(to_other), "automatic to ashford")
	_ok(sim.buy_automatic_transport(2), "automatic to millbrook")

	assert_eq(sim.warehouse(1).held_market_ids, [MARKET] as Array[StringName], "ashford has its full demand")
	# The widgets arrive in the warehouse at 25 s, before those starts.
	sim.tick(TRANSIT_MS + 1)
	assert_eq(sim.link(to_other).automatic, LinkView.Automatic.SHIPPED)
	assert_eq(sim.link(2).automatic, LinkView.Automatic.HELD)


func test_a_threshold_does_not_hold_links_to_factories() -> void:
	var sim := _saturated_game()
	_ok(sim.build_factory(&"purple"), "purple factory")
	var to_factory: int = _ok(sim.link_warehouse_to_factory(1, 2), "link to the purple factory")
	_ok(sim.set_sell_threshold(1, 1000), "a threshold that always holds from markets")
	_ok(sim.buy_automatic_transport(to_factory), "automatic to the factory")
	_ok(sim.buy_automatic_transport(2), "automatic to millbrook")
	sim.tick(TRANSIT_MS + 1)

	assert_eq(sim.link(to_factory).automatic, LinkView.Automatic.SHIPPED)
	assert_eq(sim.warehouse(1).held_market_ids, [MARKET] as Array[StringName])


func test_a_threshold_on_one_warehouse_does_not_hold_another() -> void:
	var sim := _saturated_game()
	_ok(sim.build_warehouse(&"red"), "second warehouse")
	var out: int = _ok(sim.link_warehouse_to_market(2, MARKET), "link out of the second")
	_ok(sim.buy_automatic_transport(out), "automatic out of the second")
	_ok(sim.buy_automatic_transport(2), "automatic out of the first")
	_ok(sim.set_sell_threshold(1, 80), "threshold on the first")

	assert_true(sim.warehouse(1).holds())
	assert_false(sim.warehouse(2).holds())


# --- Splits ----------------------------------------------------------------------

func test_a_held_link_keeps_its_share_of_a_split() -> void:
	var sim := _saturated_game()
	var free: int = _ok(sim.link_warehouse_to_market(1, OTHER_MARKET), "link to ashford")
	for id in [2, free]:
		_ok(sim.buy_automatic_transport(id), "automatic #%d" % id)
	_ok(sim.set_split({2: 50, free: 50}), "split")
	_ok(sim.set_sell_threshold(1, 80), "threshold")

	# At 25 s, 10 widgets arrive in the warehouse. Millbrook has 67% demand,
	# so link 2 holds, and ashford gets its 50%.
	sim.tick(TRANSIT_MS + 1)
	assert_eq(sim.splits()[0].shipped, {2: 0, free: 5} as Dictionary[int, int])
	assert_eq(sim.warehouse(1).count, 5, "the held share waits in the warehouse")

	# At 30 s, millbrook is back at 100%, and link 2 catches up to its share.
	sim.tick(TRANSIT_MS)
	assert_eq(sim.splits()[0].shipped, {2: 5, free: 5} as Dictionary[int, int])
	assert_eq(sim.warehouse(1).count, 0)


# --- Time ------------------------------------------------------------------------

func _play(sim: Simulation, ticks: Array[int]) -> void:
	_ok(sim.build_factory(&"red"), "factory")
	_ok(sim.add_production_line(1), "line")
	_ok(sim.build_warehouse(&"red"), "warehouse")
	_ok(sim.set_sell_threshold(1, 85), "threshold")
	for id: int in [sim.link_factory_to_warehouse(1, 1).value, sim.link_warehouse_to_market(1, MARKET).value,
			sim.link_warehouse_to_market(1, OTHER_MARKET).value]:
		_ok(sim.buy_automatic_transport(id), "automatic #%d" % id)
	for duration in ticks:
		sim.tick(duration)


func test_one_long_tick_gives_the_same_state_as_many_short_ticks() -> void:
	var one := _sim(12)
	var many := _sim(12)

	_play(one, [90_321])
	var short: Array[int] = []
	for i in 90:
		short.append(1000)
	short.append(321)
	_play(many, short)

	assert_eq(many.snapshot(), one.snapshot())
	var statuses := {}
	for link in one.links():
		statuses[link.automatic] = true
	assert_true(statuses.has(LinkView.Automatic.HELD), "the game holds at some time")


func test_offline_progress_holds_as_ticks_do() -> void:
	var offline := _sim(12)
	var ticked := _sim(12)
	_play(offline, [])
	_play(ticked, [])

	offline.progress_offline(600_000)
	var held_once := false
	for i in 600:
		ticked.tick(1000)
		for link in ticked.links():
			held_once = held_once or link.automatic == LinkView.Automatic.HELD

	assert_true(held_once, "the game holds at some time")
	assert_eq(offline.snapshot(), ticked.snapshot())


# --- Prestige --------------------------------------------------------------------

func test_a_prestige_clears_sell_thresholds_with_the_warehouses() -> void:
	var sim := _sim()
	_ok(sim.build_warehouse(&"red"), "warehouse")
	_ok(sim.set_sell_threshold(1, 80), "threshold")
	_ok(sim.buy_prism(), "prism")

	_ok(sim.prestige(), "prestige")
	_ok(sim.build_warehouse(&"red"), "a new warehouse")

	assert_eq(sim.warehouse(1).sell_threshold, WarehouseView.NO_SELL_THRESHOLD)
