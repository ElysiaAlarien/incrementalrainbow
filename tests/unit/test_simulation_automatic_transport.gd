extends GutTest
## Automatic transport on links, and the throughput of each link.

const SEED := 7
const MARKET := &"millbrook"


## One widget each second, an output bay of 10, factories that cost 10, carts
## that take [param transit_time_ms] and cost [param shipment_cost], and
## automatic transport that costs [param automatic_cost].
func _sim(starting_money: float = 100, transit_time_ms: int = 5000, shipment_cost: float = 2,
		automatic_cost: float = 20, price: float = 5) -> Simulation:
	var colors := ContentFixture.colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": starting_money}),
		ContentFixture.markets_data(price, colors),
		ContentFixture.transport_data(transit_time_ms, shipment_cost, automatic_cost)))
	return Simulation.new(content, SEED)


## Builds a factory of [param color] and links it to the market.
func _linked_factory(sim: Simulation, color: StringName = &"red") -> int:
	var built := sim.build_factory(color)
	assert_true(built.ok, built.message)
	var linked := sim.make_link(built.value, MARKET)
	assert_true(linked.ok, linked.message)
	return linked.value


func _automatic_link(sim: Simulation, color: StringName = &"red") -> int:
	var link_id := _linked_factory(sim, color)
	var bought := sim.buy_automatic_transport(link_id)
	assert_true(bought.ok, bought.message)
	return link_id


func _assert_money(sim: Simulation, expected: float) -> void:
	assert_true(sim.money().equals(BigNumber.from_float(expected)),
		"money should be %s, got %s" % [expected, sim.money().format()])


# --- Buying automatic transport --------------------------------------------------

func test_a_new_link_is_manual() -> void:
	var sim := _sim()
	var link := sim.link(_linked_factory(sim))

	assert_false(link.is_automatic())
	assert_eq(link.automatic, LinkView.Automatic.MANUAL)
	assert_eq(link.next_automatic_in_ms, 0)


func test_buying_automatic_transport_costs_money_and_makes_the_link_automatic() -> void:
	var sim := _sim(100, 5000, 2, 20)
	var link_id := _linked_factory(sim)
	assert_true(sim.automatic_transport_cost().equals(BigNumber.from_int(20)))

	var result := sim.buy_automatic_transport(link_id)

	assert_true(result.ok, result.message)
	_assert_money(sim, 100 - 10 - 20)
	var link := sim.link(link_id)
	assert_true(link.is_automatic())
	assert_eq(link.automatic, LinkView.Automatic.READY)
	assert_eq(link.next_automatic_in_ms, 0, "the first automatic start is now")


func test_automatic_transport_is_for_one_link_only() -> void:
	var sim := _sim()
	var red := _automatic_link(sim, &"red")
	var blue := _linked_factory(sim, &"blue")

	assert_true(sim.link(red).is_automatic())
	assert_false(sim.link(blue).is_automatic())


func test_automatic_transport_with_too_little_money_fails_and_changes_nothing() -> void:
	var sim := _sim(29, 5000, 2, 20)
	var link_id := _linked_factory(sim)
	var before := sim.snapshot()

	var result := sim.buy_automatic_transport(link_id)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_MONEY)
	assert_eq(result.message, "Automatic transport costs 20, but you have only 19.")
	assert_eq(sim.snapshot(), before)


func test_the_last_money_can_buy_automatic_transport() -> void:
	var sim := _sim(30, 5000, 2, 20)
	var link_id := _linked_factory(sim)

	assert_true(sim.buy_automatic_transport(link_id).ok)
	_assert_money(sim, 0)


func test_automatic_transport_on_an_unknown_link_fails_and_changes_nothing() -> void:
	var sim := _sim()
	_linked_factory(sim)
	var before := sim.snapshot()

	var result := sim.buy_automatic_transport(99)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_LINK)
	assert_eq(sim.snapshot(), before)


func test_automatic_transport_twice_on_one_link_fails_and_changes_nothing() -> void:
	var sim := _sim()
	var link_id := _automatic_link(sim)
	var before := sim.snapshot()

	var result := sim.buy_automatic_transport(link_id)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.ALREADY_AUTOMATIC)
	assert_eq(sim.snapshot(), before)


# --- Automatic shipments -------------------------------------------------------

func test_an_automatic_link_starts_a_shipment_with_no_command() -> void:
	var sim := _sim(100, 5000, 2, 20)
	var link_id := _linked_factory(sim)
	sim.tick(3000)
	assert_true(sim.buy_automatic_transport(link_id).ok)

	sim.tick(1)

	var link := sim.link(link_id)
	assert_eq(link.automatic, LinkView.Automatic.SHIPPED)
	assert_eq(link.shipments_in_transit.size(), 1)
	assert_eq(link.shipments_in_transit[0].count, 3, "it takes the whole output bay")
	assert_eq(link.next_automatic_in_ms, 4999, "the next start is one transit time later")
	assert_eq(sim.factory(1).output_bay_count, 0)
	_assert_money(sim, 100 - 10 - 20 - 2)


func test_an_automatic_shipment_takes_the_transit_time_and_sells() -> void:
	var sim := _sim(100, 5000, 2, 20, 5)
	var link_id := _linked_factory(sim)
	sim.tick(3000)
	assert_true(sim.buy_automatic_transport(link_id).ok)
	sim.tick(4999)
	_assert_money(sim, 68)
	assert_eq(sim.link(link_id).shipments_in_transit[0].remaining_ms, 1)

	sim.tick(1)

	# The 3 widgets sell for 5 each. The tick ends at the time of the second
	# start, so the next tick does it.
	_assert_money(sim, 68 + 15)
	assert_eq(sim.link(link_id).shipments_in_transit.size(), 0)
	assert_eq(sim.link(link_id).next_automatic_in_ms, 0)

	sim.tick(1)

	_assert_money(sim, 68 + 15 - 2)
	var link := sim.link(link_id)
	assert_eq(link.shipments_in_transit.size(), 1)
	assert_eq(link.shipments_in_transit[0].count, 5, "the widgets made since the first start")


func test_an_automatic_link_starts_once_each_transit_time() -> void:
	var sim := _sim(1000, 2000, 1, 20)
	var link_id := _automatic_link(sim)

	sim.tick(10_000)

	# Starts at 0, 2, 4, 6, and 8 seconds. The first has nothing to ship. Each
	# other start ships 2 widgets, which sell 2 seconds later.
	var link := sim.link(link_id)
	assert_eq(link.automatic, LinkView.Automatic.SHIPPED)
	assert_eq(link.next_automatic_in_ms, 0, "the start at 10 seconds is next")
	assert_eq(sim.factory(1).output_bay_count, 2)
	_assert_money(sim, 1000 - 10 - 20 - 4 * 1 + 4 * 2 * 5)
	assert_eq(link.shipments_in_transit.size(), 0)


func test_an_automatic_start_with_too_little_money_sends_nothing_and_shows_why() -> void:
	var sim := _sim(31, 5000, 2, 20)
	var link_id := _linked_factory(sim)
	sim.tick(4000)
	assert_true(sim.buy_automatic_transport(link_id).ok)
	_assert_money(sim, 1)

	sim.tick(1)

	var link := sim.link(link_id)
	assert_eq(link.automatic, LinkView.Automatic.NOT_ENOUGH_MONEY)
	assert_eq(link.shipments_in_transit.size(), 0)
	assert_eq(sim.factory(1).output_bay_count, 4, "the widgets stay in the output bay")
	_assert_money(sim, 1)


func test_an_automatic_start_with_nothing_to_ship_shows_why() -> void:
	var sim := _sim()
	var link_id := _automatic_link(sim)

	sim.tick(1)

	var link := sim.link(link_id)
	assert_eq(link.automatic, LinkView.Automatic.NOTHING_TO_SHIP)
	assert_eq(link.shipments_in_transit.size(), 0)
	_assert_money(sim, 100 - 10 - 20)


func test_an_automatic_link_ships_again_when_money_comes_back() -> void:
	var sim := _sim(32, 3000, 2, 20)
	var link_id := _linked_factory(sim)
	sim.tick(2000)
	assert_true(sim.buy_automatic_transport(link_id).ok)
	# Money 2: the first start ships 2 widgets for the last 2 money.
	sim.tick(1)
	assert_eq(sim.link(link_id).automatic, LinkView.Automatic.SHIPPED)
	_assert_money(sim, 0)

	# At 5 seconds the shipment sells for 10 before the next start, which
	# then has the money it needs.
	sim.tick(3000)

	assert_eq(sim.link(link_id).automatic, LinkView.Automatic.SHIPPED)
	_assert_money(sim, 10 - 2)


func test_a_manual_shipment_on_an_automatic_link_still_works() -> void:
	var sim := _sim()
	var link_id := _automatic_link(sim)
	sim.tick(2500)

	var result := sim.start_shipment(link_id)

	assert_true(result.ok, result.message)
	assert_eq(result.value, 2)
	assert_eq(sim.link(link_id).shipments_in_transit.size(), 1)


func test_a_manual_link_ships_nothing_by_itself() -> void:
	var sim := _sim()
	var link_id := _linked_factory(sim)

	sim.tick(60_000)

	assert_eq(sim.link(link_id).shipments_in_transit.size(), 0)
	assert_eq(sim.factory(1).output_bay_count, 10)


# --- Throughput ----------------------------------------------------------------

func test_a_new_link_has_no_throughput() -> void:
	var sim := _sim()
	assert_eq(sim.link(_linked_factory(sim)).widgets_per_minute, 0)


func test_throughput_counts_the_widgets_that_started_in_the_last_minute() -> void:
	var sim := _sim(1000, 5000, 1, 20)
	var link_id := _linked_factory(sim)
	sim.tick(4000)
	sim.start_shipment(link_id)
	sim.tick(3000)
	sim.start_shipment(link_id)
	assert_eq(sim.link(link_id).widgets_per_minute, 4 + 3, "manual shipments count")

	sim.tick(57_000)
	assert_eq(sim.link(link_id).widgets_per_minute, 3, "the first start is a minute old")

	sim.tick(3000)
	assert_eq(sim.link(link_id).widgets_per_minute, 0)


func test_throughput_shows_the_limit_of_an_automatic_link() -> void:
	# Three lines make 3 widgets each second, but a cart takes at most the 10
	# widgets of the output bay each 5 seconds.
	var sim := _sim(1000, 5000, 1, 20)
	var link_id := _automatic_link(sim)
	sim.add_production_line(1)
	sim.add_production_line(1)

	sim.tick(124_000)

	assert_eq(sim.link(link_id).widgets_per_minute, 12 * 10, "starts at 65 to 120 seconds")
	assert_true(sim.factory(1).is_stopped(), "the link is the bottleneck")


func test_throughput_of_each_link_is_its_own() -> void:
	var sim := _sim(1000, 5000, 1, 20)
	var red := _automatic_link(sim, &"red")
	var blue := _linked_factory(sim, &"blue")

	sim.tick(60_000)

	assert_eq(sim.link(red).widgets_per_minute, 55, "starts at 5 to 55 seconds, 5 widgets each")
	assert_eq(sim.link(blue).widgets_per_minute, 0)


# --- Ticks ---------------------------------------------------------------------

func _play(sim: Simulation, ticks: Array[int]) -> void:
	# Prices with decimals, two automatic links with different transit times,
	# low money, and a manual shipment, so that the order of events matters.
	var red := _automatic_link(sim, &"red")
	sim.tick(1700)
	var blue := _linked_factory(sim, &"blue")
	sim.add_production_line(2)
	sim.buy_automatic_transport(blue)
	sim.tick(900)
	sim.start_shipment(red)
	for duration in ticks:
		sim.tick(duration)


func test_one_long_tick_gives_the_same_state_as_many_short_ticks() -> void:
	# A shipment of 2 widgets sells for less than it costs, so money runs out.
	var one := _sim(61.3, 2300, 1.7, 5, 0.37)
	var many := _sim(61.3, 2300, 1.7, 5, 0.37)
	var short_ticks: Array[int] = []
	for i in 400:
		short_ticks.append(1 + i % 7 * 61)
	var total := 0
	for duration in short_ticks:
		total += duration

	_play(one, [total])
	_play(many, short_ticks)

	assert_eq(one.snapshot(), many.snapshot())
	assert_eq(one.link(2).automatic, LinkView.Automatic.NOT_ENOUGH_MONEY, "money ran out")


func test_ticks_that_end_on_an_event_give_the_same_state() -> void:
	var one := _sim(100, 2000, 1, 20)
	var many := _sim(100, 2000, 1, 20)
	_automatic_link(one)
	_automatic_link(many)

	one.tick(8000)
	for i in 4:
		many.tick(2000)

	assert_eq(one.snapshot(), many.snapshot())
