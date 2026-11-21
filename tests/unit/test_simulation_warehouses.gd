extends GutTest
## Warehouses: building them when they are unlocked, links to and from them,
## the shipment size rule for free warehouse space, and their throughput.

const SEED := 13
const MARKET := &"millbrook"
const TRANSIT_MS := 5000
const PRICE := ContentFixture.PRICE


## One widget per second for each line, output bays of 10, shipments that cost
## 2 and take 5 seconds, and much money, so that money never limits a test.
## Warehouses hold [param space] widgets and unlock at [param unlock_factories]
## factories.
func _sim(space: int = 20, unlock_factories: int = 0, starting_money: float = 10_000) -> Simulation:
	var content := ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(1000, 10, {"starting_money": starting_money, "space": space,
			"unlock_factory_count": unlock_factories}),
		null, ContentFixture.transport_data(TRANSIT_MS, 2)))
	return Simulation.new(content, SEED)


func _ok(result: CommandResult, what: String) -> Variant:
	assert_true(result.ok, "%s: %s" % [what, result.message])
	return result.value


func _factory(sim: Simulation, color: StringName) -> int:
	return _ok(sim.build_factory(color), "build %s factory" % color)


func _warehouse(sim: Simulation, color: StringName) -> int:
	return _ok(sim.build_warehouse(color), "build %s warehouse" % color)


func _ship(sim: Simulation, link_id: int) -> int:
	return _ok(sim.start_shipment(link_id), "ship on link #%d" % link_id)


func _assert_fails(sim: Simulation, result: CommandResult, reason: CommandResult.Reason,
		message_part: String, before: Dictionary) -> void:
	assert_false(result.ok, "the command fails")
	assert_eq(result.reason, reason, result.message)
	assert_string_contains(result.message, message_part)
	assert_eq(sim.snapshot(), before, "the state does not change")


## A red factory with a full output bay and a link from it to a red
## warehouse. Returns [code][factory, warehouse, link][/code].
func _red_line(sim: Simulation) -> Array[int]:
	var factory := _factory(sim, &"red")
	var warehouse := _warehouse(sim, &"red")
	sim.tick(10_000)
	return [factory, warehouse, _ok(sim.link_factory_to_warehouse(factory, warehouse), "link to warehouse")]


# --- Building ------------------------------------------------------------------

func test_a_warehouse_costs_money_and_starts_empty() -> void:
	var sim := _sim(20, 0, 100)

	var id: int = _warehouse(sim, &"blue")

	assert_eq(id, 1)
	assert_eq(sim.money().format(), str(100 - ContentFixture.WAREHOUSE_COST))
	var view := sim.warehouse(id)
	assert_eq([view.id, view.color, view.count, view.space, view.in_transit], [1, &"blue", 0, 20, 0])
	assert_eq([view.inflow_per_minute, view.outflow_per_minute], [0, 0])
	assert_eq(sim.warehouses().size(), 1)
	assert_eq(_warehouse(sim, &"blue"), 2, "a second warehouse of one color is allowed")


func test_a_warehouse_can_hold_a_mixed_color() -> void:
	var sim := _sim()
	assert_eq(sim.warehouse(_warehouse(sim, &"green")).color, &"green")


func test_warehouses_are_locked_until_the_player_has_enough_factories() -> void:
	var sim := _sim(20, 2)
	assert_false(sim.is_warehouse_unlocked())
	var before := sim.snapshot()
	_assert_fails(sim, sim.build_warehouse(&"red"), CommandResult.Reason.WAREHOUSE_LOCKED,
		"Warehouses unlock when you have 2 factories", before)

	_factory(sim, &"red")
	assert_false(sim.is_warehouse_unlocked(), "one factory is not enough")
	_factory(sim, &"blue")

	assert_true(sim.is_warehouse_unlocked())
	assert_true(sim.build_warehouse(&"red").ok)


func test_a_warehouse_with_too_little_money_fails() -> void:
	var sim := _sim(20, 0, ContentFixture.WAREHOUSE_COST - 1)
	var before := sim.snapshot()
	_assert_fails(sim, sim.build_warehouse(&"red"), CommandResult.Reason.NOT_ENOUGH_MONEY,
		"A warehouse costs %d" % ContentFixture.WAREHOUSE_COST, before)


func test_a_warehouse_of_an_unknown_color_fails() -> void:
	var sim := _sim()
	var before := sim.snapshot()
	_assert_fails(sim, sim.build_warehouse(&"magenta"), CommandResult.Reason.UNKNOWN_COLOR,
		"There is no color \"magenta\"", before)


func test_an_unknown_warehouse_is_null() -> void:
	assert_null(_sim().warehouse(1))


# --- Links ---------------------------------------------------------------------

func test_a_factory_links_to_a_warehouse_of_its_color() -> void:
	var sim := _sim()
	var line := _red_line(sim)

	var view := sim.link(line[2])

	assert_eq([view.color, view.source_kind, view.source_factory_id], [&"red", LinkView.Source.FACTORY, line[0]])
	assert_eq([view.destination_kind, view.destination_warehouse_id], [LinkView.Destination.WAREHOUSE, line[1]])
	assert_eq(view.vehicle, &"cart")


func test_a_link_from_a_factory_to_a_warehouse_of_another_color_fails() -> void:
	var sim := _sim()
	var factory := _factory(sim, &"red")
	var warehouse := _warehouse(sim, &"blue")
	var before := sim.snapshot()
	_assert_fails(sim, sim.link_factory_to_warehouse(factory, warehouse), CommandResult.Reason.WRONG_COLOR,
		"Blue warehouse #1 holds blue, but Red factory #1 makes red", before)


func test_a_warehouse_links_to_a_market_and_to_a_factory() -> void:
	var sim := _sim()
	var warehouse := _warehouse(sim, &"yellow")
	var green := _factory(sim, &"green")

	var to_market: int = _ok(sim.link_warehouse_to_market(warehouse, MARKET), "to market")
	var to_factory: int = _ok(sim.link_warehouse_to_factory(warehouse, green), "to factory")

	var view := sim.link(to_market)
	assert_eq([view.color, view.source_kind, view.source_warehouse_id, view.source_factory_id],
		[&"yellow", LinkView.Source.WAREHOUSE, warehouse, 0])
	assert_eq([view.destination_kind, view.destination_market_id], [LinkView.Destination.MARKET, MARKET])
	view = sim.link(to_factory)
	assert_eq([view.color, view.source_warehouse_id], [&"yellow", warehouse])
	assert_eq([view.destination_kind, view.destination_factory_id], [LinkView.Destination.FACTORY, green])


func test_a_link_from_a_warehouse_to_a_factory_that_does_not_use_its_color_fails() -> void:
	var sim := _sim()
	var warehouse := _warehouse(sim, &"red")
	var green := _factory(sim, &"green")
	var before := sim.snapshot()
	_assert_fails(sim, sim.link_warehouse_to_factory(warehouse, green), CommandResult.Reason.NOT_A_RECIPE_INPUT,
		"Green factory #1 does not use red", before)


func test_links_with_unknown_ends_fail() -> void:
	var sim := _sim()
	var factory := _factory(sim, &"red")
	var warehouse := _warehouse(sim, &"red")
	var before := sim.snapshot()
	_assert_fails(sim, sim.link_factory_to_warehouse(factory, 9), CommandResult.Reason.UNKNOWN_WAREHOUSE,
		"There is no warehouse #9", before)
	_assert_fails(sim, sim.link_factory_to_warehouse(9, warehouse), CommandResult.Reason.UNKNOWN_FACTORY,
		"There is no factory #9", before)
	_assert_fails(sim, sim.link_warehouse_to_market(9, MARKET), CommandResult.Reason.UNKNOWN_WAREHOUSE,
		"There is no warehouse #9", before)
	_assert_fails(sim, sim.link_warehouse_to_market(warehouse, &"atlantis"), CommandResult.Reason.UNKNOWN_MARKET,
		"There is no market \"atlantis\"", before)
	_assert_fails(sim, sim.link_warehouse_to_factory(9, factory), CommandResult.Reason.UNKNOWN_WAREHOUSE,
		"There is no warehouse #9", before)
	_assert_fails(sim, sim.link_warehouse_to_factory(warehouse, 9), CommandResult.Reason.UNKNOWN_FACTORY,
		"There is no factory #9", before)


func test_a_second_link_between_the_same_ends_fails() -> void:
	var sim := _sim()
	var factory := _factory(sim, &"yellow")
	var green := _factory(sim, &"green")
	var warehouse := _warehouse(sim, &"yellow")
	sim.link_factory_to_warehouse(factory, warehouse)
	sim.link_warehouse_to_market(warehouse, MARKET)
	sim.link_warehouse_to_factory(warehouse, green)
	var before := sim.snapshot()

	_assert_fails(sim, sim.link_factory_to_warehouse(factory, warehouse), CommandResult.Reason.LINK_EXISTS,
		"Yellow factory #1 already has a link to Yellow warehouse #1", before)
	_assert_fails(sim, sim.link_warehouse_to_market(warehouse, MARKET), CommandResult.Reason.LINK_EXISTS,
		"Yellow warehouse #1 already has a link to Millbrook", before)
	_assert_fails(sim, sim.link_warehouse_to_factory(warehouse, green), CommandResult.Reason.LINK_EXISTS,
		"Yellow warehouse #1 already has a link to Green factory #2", before)


func test_a_warehouse_and_a_factory_with_the_same_id_have_their_own_links() -> void:
	# Warehouse #1 and factory #1 are different places.
	var sim := _sim()
	var factory := _factory(sim, &"red")
	var warehouse := _warehouse(sim, &"red")
	assert_eq(factory, warehouse)
	_ok(sim.make_link(factory, MARKET), "factory to market")

	_ok(sim.link_warehouse_to_market(warehouse, MARKET), "warehouse to market")

	assert_true(sim.has_link(factory, MARKET))
	assert_eq(sim.links().size(), 2)


# --- Shipment size -------------------------------------------------------------

func test_a_shipment_to_a_warehouse_carries_the_widgets_and_the_warehouse_holds_them() -> void:
	var sim := _sim()
	var line := _red_line(sim)

	assert_eq(_ship(sim, line[2]), 10)
	assert_eq(sim.warehouse(line[1]).in_transit, 10)
	sim.tick(TRANSIT_MS)

	var view := sim.warehouse(line[1])
	assert_eq([view.count, view.in_transit], [10, 0])
	assert_eq(sim.factory(line[0]).output_bay_count, 5, "the factory made 5 more in the transit time")


func test_a_shipment_to_a_warehouse_carries_no_more_than_its_free_space() -> void:
	var sim := _sim(7)
	var line := _red_line(sim)

	assert_eq(_ship(sim, line[2]), 7, "the warehouse has space for 7 of the 10 widgets")
	assert_eq(sim.factory(line[0]).output_bay_count, 3, "3 widgets stay in the output bay")


func test_the_free_space_does_not_count_widgets_on_their_way() -> void:
	var sim := _sim(15)
	var line := _red_line(sim)
	_ship(sim, line[2])
	sim.tick(1000)

	assert_eq(_ship(sim, line[2]), 1, "10 are on their way, so 5 of the 15 are free, and the bay has 1")
	sim.tick(4000)
	assert_eq(_ship(sim, line[2]), 4, "10 arrived, 1 is on its way, so 4 are free")
	assert_eq(sim.warehouse(line[1]).free_space(), 0)


func test_a_shipment_to_a_full_warehouse_fails_with_a_reason() -> void:
	var sim := _sim(10)
	var line := _red_line(sim)
	_ship(sim, line[2])
	sim.tick(TRANSIT_MS)
	var before := sim.snapshot()

	_assert_fails(sim, sim.start_shipment(line[2]), CommandResult.Reason.NOTHING_TO_SHIP,
		"Red warehouse #1 is full, with the widgets on the way", before)


func test_a_shipment_from_an_empty_warehouse_fails_with_a_reason() -> void:
	var sim := _sim()
	var warehouse := _warehouse(sim, &"red")
	var link: int = _ok(sim.link_warehouse_to_market(warehouse, MARKET), "link")
	var before := sim.snapshot()

	_assert_fails(sim, sim.start_shipment(link), CommandResult.Reason.NOTHING_TO_SHIP,
		"Red warehouse #1 has no widgets", before)


func test_a_warehouse_ships_to_a_market_which_sells_the_widgets() -> void:
	var sim := _sim()
	var line := _red_line(sim)
	_ship(sim, line[2])
	sim.tick(TRANSIT_MS)
	var out: int = _ok(sim.link_warehouse_to_market(line[1], MARKET), "link to market")
	var money := sim.money()

	assert_eq(_ship(sim, out), 10)
	assert_eq(sim.warehouse(line[1]).count, 0)
	sim.tick(TRANSIT_MS)

	assert_true(sim.money().equals(money.sub(BigNumber.from_int(2)).add(BigNumber.from_int(10 * PRICE))),
		"money %s" % sim.money().format())


func test_a_warehouse_ships_to_a_mixed_factory_up_to_its_free_input_bay_space() -> void:
	var sim := _sim()
	var yellow := _factory(sim, &"yellow")
	var green := _factory(sim, &"green")
	var warehouse := _warehouse(sim, &"yellow")
	sim.tick(10_000)
	var in_link: int = _ok(sim.link_factory_to_warehouse(yellow, warehouse), "in")
	_ship(sim, in_link)
	sim.tick(TRANSIT_MS)
	_ship(sim, in_link)
	sim.tick(TRANSIT_MS)
	assert_eq(sim.warehouse(warehouse).count, 15)
	var out: int = _ok(sim.link_warehouse_to_factory(warehouse, green), "out")

	assert_eq(_ship(sim, out), ContentFixture.INPUT_BAY_CAPACITY, "the input bay holds 10")
	sim.tick(TRANSIT_MS)

	assert_eq(sim.warehouse(warehouse).count, 5)
	assert_eq(sim.factory(green).input_bays[0].count, ContentFixture.INPUT_BAY_CAPACITY)


# --- Inflow and outflow --------------------------------------------------------

func test_the_inflow_and_the_outflow_of_a_warehouse_can_be_different() -> void:
	var sim := _sim(100)
	var red := _factory(sim, &"red")
	var second_red := _factory(sim, &"red")
	var warehouse := _warehouse(sim, &"red")
	sim.tick(10_000)
	var first_in: int = _ok(sim.link_factory_to_warehouse(red, warehouse), "first in")
	var second_in: int = _ok(sim.link_factory_to_warehouse(second_red, warehouse), "second in")
	var out: int = _ok(sim.link_warehouse_to_market(warehouse, MARKET), "out")
	_ship(sim, first_in)
	_ship(sim, second_in)
	sim.tick(TRANSIT_MS)

	sim.start_shipment(out)

	var view := sim.warehouse(warehouse)
	assert_eq(view.inflow_per_minute, 20, "two links carried 10 each to the warehouse")
	assert_eq(view.outflow_per_minute, 20, "the warehouse sent all 20 at once")
	sim.tick(TRANSIT_MS)
	_ship(sim, first_in)
	sim.tick(TRANSIT_MS)
	view = sim.warehouse(warehouse)
	assert_eq([view.inflow_per_minute, view.outflow_per_minute, view.count], [30, 20, 10],
		"widgets came in, but none went out, so the warehouse holds them")


func test_throughput_of_a_warehouse_counts_only_the_last_minute() -> void:
	var sim := _sim()
	var line := _red_line(sim)
	_ship(sim, line[2])

	sim.tick(60_000)

	assert_eq(sim.warehouse(line[1]).inflow_per_minute, 0)


func test_an_automatic_link_from_a_warehouse_ships_by_itself() -> void:
	var sim := _sim()
	var line := _red_line(sim)
	_ok(sim.buy_automatic_transport(line[2]), "automatic in")
	var out: int = _ok(sim.link_warehouse_to_market(line[1], MARKET), "out")
	_ok(sim.buy_automatic_transport(out), "automatic out")
	assert_eq(sim.link(out).automatic, LinkView.Automatic.READY)

	# The first start of the warehouse link finds the warehouse empty. Its
	# next start is at the arrival time, after the arrival, so the widgets
	# leave the warehouse at the time they arrive.
	sim.tick(1)
	assert_eq(sim.link(out).automatic, LinkView.Automatic.NOTHING_TO_SHIP)
	sim.tick(TRANSIT_MS)

	assert_eq(sim.link(out).automatic, LinkView.Automatic.SHIPPED)
	assert_eq(sim.warehouse(line[1]).count, 0)
	assert_eq(sim.link(out).shipments_in_transit.size(), 1)
	assert_eq(sim.link(out).shipments_in_transit[0].count, 10)


func _play(sim: Simulation, ticks: Array[int]) -> void:
	var line := _red_line(sim)
	sim.buy_automatic_transport(line[2])
	var out: int = sim.link_warehouse_to_market(line[1], MARKET).value
	sim.buy_automatic_transport(out)
	for duration in ticks:
		sim.tick(duration)


func test_one_long_tick_gives_the_same_state_as_many_short_ticks() -> void:
	var one := _sim(12)
	var many := _sim(12)

	_play(one, [61_234])
	var short: Array[int] = []
	for i in 61:
		short.append(1000)
	short.append(234)
	_play(many, short)

	assert_eq(many.snapshot(), one.snapshot())


# --- Prestige ------------------------------------------------------------------

func test_a_prestige_clears_warehouses_and_locks_them_again() -> void:
	var sim := _sim(20, 1)
	var line := _red_line(sim)
	_ship(sim, line[2])
	sim.tick(TRANSIT_MS)
	assert_gt(sim.warehouse(line[1]).count, 0)
	_ok(sim.buy_prism(), "buy a prism")

	_ok(sim.prestige(), "prestige")

	assert_eq(sim.warehouses().size(), 0, "no warehouses in the fresh run")
	assert_eq(sim.links().size(), 0)
	assert_false(sim.is_warehouse_unlocked(), "a fresh run has no factories, so warehouses are locked")
	_factory(sim, &"blue")
	assert_eq(_warehouse(sim, &"blue"), 1, "warehouse ids start at 1 again")
