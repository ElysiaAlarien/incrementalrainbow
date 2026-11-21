extends GutTest
## Links from a factory to a market, shipments on them, and the sales they make.

const SEED := 99
const MARKET := &"millbrook"


func _sim(price: float = 5, transit_time_ms: int = 5000, shipment_cost: float = 2,
		starting_money: float = 100) -> Simulation:
	# One widget each second, an output bay of 10, and factories that cost 10.
	var colors := ContentFixture.colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": starting_money}),
		ContentFixture.markets_data(price, colors),
		ContentFixture.transport_data(transit_time_ms, shipment_cost)))
	return Simulation.new(content, SEED)


func _build(sim: Simulation, color: StringName) -> int:
	var result := sim.build_factory(color)
	assert_true(result.ok, "build %s: %s" % [color, result.message])
	return result.value


func _link(sim: Simulation, factory_id: int, market: StringName = MARKET) -> int:
	var result := sim.make_link(factory_id, market)
	assert_true(result.ok, "link: %s" % result.message)
	return result.value


func _assert_money(sim: Simulation, expected: int) -> void:
	assert_true(sim.money().equals(BigNumber.from_int(expected)),
		"money should be %d, got %s" % [expected, sim.money()])


# --- Markets and links ---------------------------------------------------------

func test_a_run_starts_with_one_market_and_its_prices() -> void:
	var sim := _sim(7)
	var markets := sim.markets()
	assert_eq(markets.size(), 1)
	assert_eq(markets[0].id, MARKET)
	assert_eq(markets[0].name, "Millbrook")
	assert_true(markets[0].price(&"blue").equals(BigNumber.from_int(7)))
	assert_eq(sim.market(MARKET).id, MARKET)
	assert_null(sim.market(&"nowhere"))


func test_a_link_carries_the_factory_color_to_the_market_by_cart() -> void:
	var sim := _sim(5, 8000, 3)
	var factory_id := _build(sim, &"yellow")

	assert_false(sim.has_link(factory_id, MARKET))
	var link_id := _link(sim, factory_id)

	assert_true(sim.has_link(factory_id, MARKET))
	var link := sim.link(link_id)
	assert_eq(link.id, link_id)
	assert_eq(link.color, &"yellow")
	assert_eq(link.source_factory_id, factory_id)
	assert_eq(link.destination_market_id, MARKET)
	assert_eq(link.vehicle, &"cart")
	assert_eq(link.transit_time_ms, 8000)
	assert_true(link.shipment_cost.equals(BigNumber.from_int(3)))
	assert_eq(link.shipments_in_transit.size(), 0)
	assert_eq(sim.links().size(), 1)


func test_making_a_link_is_free() -> void:
	var sim := _sim()
	var factory_id := _build(sim, &"red")
	_link(sim, factory_id)
	_assert_money(sim, 90)


func test_each_factory_can_have_its_own_link() -> void:
	var sim := _sim()
	var red := _link(sim, _build(sim, &"red"))
	var blue := _link(sim, _build(sim, &"blue"))
	assert_ne(red, blue)
	assert_eq(sim.links().map(func(l: LinkView) -> StringName: return l.color), [&"red", &"blue"])


func test_a_link_to_an_unknown_factory_fails_and_changes_nothing() -> void:
	var sim := _sim()
	_build(sim, &"red")
	var before := sim.snapshot()
	var result := sim.make_link(42, MARKET)
	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_FACTORY)
	assert_eq(sim.snapshot(), before)


func test_a_link_to_an_unknown_market_fails_and_changes_nothing() -> void:
	var sim := _sim()
	var factory_id := _build(sim, &"red")
	var before := sim.snapshot()
	var result := sim.make_link(factory_id, &"atlantis")
	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_MARKET)
	assert_string_contains(result.message, "atlantis")
	assert_eq(sim.snapshot(), before)


func test_a_second_link_from_a_factory_to_the_same_market_fails() -> void:
	var sim := _sim()
	var factory_id := _build(sim, &"red")
	_link(sim, factory_id)
	var before := sim.snapshot()
	var result := sim.make_link(factory_id, MARKET)
	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.LINK_EXISTS)
	assert_eq(sim.snapshot(), before)


func test_link_queries_return_copies() -> void:
	var sim := _sim()
	var link_id := _link(sim, _build(sim, &"red"))
	sim.link(link_id).color = &"blue"
	sim.links().clear()
	assert_eq(sim.link(link_id).color, &"red")
	assert_eq(sim.links().size(), 1)
	assert_null(sim.link(link_id + 1))


# --- Shipments and sales -------------------------------------------------------

func test_a_shipment_takes_every_widget_in_the_output_bay() -> void:
	var sim := _sim(5, 5000, 2)
	var factory_id := _build(sim, &"red")
	var link_id := _link(sim, factory_id)
	sim.tick(4000)

	var result := sim.start_shipment(link_id)

	assert_true(result.ok, result.message)
	assert_eq(result.value, 4, "the value is the widget count")
	assert_eq(sim.factory(factory_id).output_bay_count, 0)
	var shipments := sim.link(link_id).shipments_in_transit
	assert_eq(shipments.size(), 1)
	assert_eq(shipments[0].count, 4)
	assert_eq(shipments[0].remaining_ms, 5000)


func test_a_shipment_costs_money_when_it_starts() -> void:
	var sim := _sim(5, 5000, 2)
	var link_id := _link(sim, _build(sim, &"red"))
	sim.tick(3000)
	sim.start_shipment(link_id)
	_assert_money(sim, 100 - 10 - 2)


func test_the_market_sells_a_shipment_when_it_arrives() -> void:
	var sim := _sim(5, 5000, 2)
	var factory_id := _build(sim, &"red")
	var link_id := _link(sim, factory_id)
	sim.tick(3000)
	sim.start_shipment(link_id)

	sim.tick(4999)
	_assert_money(sim, 88)
	assert_eq(sim.link(link_id).shipments_in_transit[0].remaining_ms, 1)

	sim.tick(1)
	_assert_money(sim, 88 + 3 * 5)
	assert_eq(sim.link(link_id).shipments_in_transit.size(), 0)


func test_the_sale_uses_the_price_of_the_shipment_color() -> void:
	var colors := ContentFixture.colors_data()
	var markets := {"markets": [{"id": "millbrook", "name": "Millbrook",
		"population": ContentFixture.POPULATION, "income": ContentFixture.INCOME,
		"prices": {"red": 1, "yellow": 2.5, "blue": 4}}]}
	var sim := Simulation.new(ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(), markets,
		ContentFixture.transport_data(1000, 0))), SEED)
	var link_id := _link(sim, _build(sim, &"yellow"))
	sim.tick(2000)
	sim.start_shipment(link_id)
	sim.tick(1000)
	_assert_money(sim, 90 + 5)


func test_a_shipment_restarts_a_factory_that_stopped_on_a_full_bay() -> void:
	var sim := _sim()
	var factory_id := _build(sim, &"blue")
	var link_id := _link(sim, factory_id)
	sim.tick(60_000)
	assert_true(sim.factory(factory_id).is_stopped())

	sim.start_shipment(link_id)
	sim.tick(2000)

	assert_false(sim.factory(factory_id).is_stopped())
	assert_eq(sim.factory(factory_id).output_bay_count, 2)


func test_several_shipments_can_be_in_transit_on_one_link() -> void:
	var sim := _sim(5, 5000, 2)
	var link_id := _link(sim, _build(sim, &"red"))
	sim.tick(2000)
	sim.start_shipment(link_id)
	sim.tick(3000)
	sim.start_shipment(link_id)

	var shipments := sim.link(link_id).shipments_in_transit
	assert_eq(shipments.map(func(s: ShipmentView) -> int: return s.count), [2, 3])
	assert_eq(shipments.map(func(s: ShipmentView) -> int: return s.remaining_ms), [2000, 5000])

	sim.tick(2000)
	_assert_money(sim, 86 + 10)
	sim.tick(3000)
	_assert_money(sim, 86 + 10 + 15)


func test_the_last_money_can_pay_for_a_shipment() -> void:
	var sim := _sim(5, 5000, 2, 12)
	var link_id := _link(sim, _build(sim, &"red"))
	sim.tick(1000)
	assert_true(sim.start_shipment(link_id).ok)
	assert_true(sim.money().is_zero(), "got %s" % sim.money())


func test_a_shipment_with_too_little_money_fails_and_changes_nothing() -> void:
	var sim := _sim(5, 5000, 2, 11)
	var link_id := _link(sim, _build(sim, &"red"))
	sim.tick(1000)
	var before := sim.snapshot()

	var result := sim.start_shipment(link_id)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_MONEY)
	assert_string_contains(result.message, "2")
	assert_eq(sim.snapshot(), before)


func test_a_shipment_with_an_empty_output_bay_fails_and_changes_nothing() -> void:
	var sim := _sim()
	var link_id := _link(sim, _build(sim, &"red"))
	sim.tick(999)
	var before := sim.snapshot()

	var result := sim.start_shipment(link_id)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOTHING_TO_SHIP)
	assert_eq(sim.snapshot(), before)


func test_a_shipment_on_an_unknown_link_fails_and_changes_nothing() -> void:
	var sim := _sim()
	_link(sim, _build(sim, &"red"))
	sim.tick(3000)
	var before := sim.snapshot()

	var result := sim.start_shipment(17)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_LINK)
	assert_eq(sim.snapshot(), before)


func _ship_on_two_links(sim: Simulation, ticks: Array[int]) -> void:
	# Prices with decimals, and shipments that arrive at different times, so
	# that the order of sales matters for the sum.
	var red := _link(sim, _build(sim, &"red"))
	var blue := _link(sim, _build(sim, &"blue"))
	sim.tick(3000)
	sim.start_shipment(red)
	sim.tick(1700)
	sim.start_shipment(blue)
	sim.start_shipment(red)
	for duration in ticks:
		sim.tick(duration)


func test_one_long_tick_sells_the_same_as_many_short_ticks() -> void:
	var one := _sim(0.37, 2300, 0.11)
	var many := _sim(0.37, 2300, 0.11)
	var short_ticks: Array[int] = []
	for i in 97:
		short_ticks.append(53)

	_ship_on_two_links(one, [97 * 53])
	_ship_on_two_links(many, short_ticks)

	assert_eq(one.snapshot(), many.snapshot())
	assert_eq(one.link(1).shipments_in_transit.size(), 0, "all shipments arrived")
