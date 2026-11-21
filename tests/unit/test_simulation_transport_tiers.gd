extends GutTest
## Transport tiers, market remoteness, and the vehicle of each link.

const SEED := 11
const NEAR := &"millbrook"
const FAR := &"farpoint"
const FARTHEST := &"lastport"


## Three markets: millbrook (remoteness 0), farpoint (2), and lastport (4).
## Carts (5 s, 2 each) reach 0, trucks reach 2, and trains reach 4 (see
## [method ContentFixture.transport_data]). Mixed colors, factories that cost
## 10, and one widget each second.
func _sim(starting_money: float = 100) -> Simulation:
	var colors := ContentFixture.mixed_colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": starting_money}),
		ContentFixture.remote_markets_data(colors), ContentFixture.transport_data()))
	return Simulation.new(content, SEED)


func _build(sim: Simulation, color: StringName = &"red") -> int:
	var result := sim.build_factory(color)
	assert_true(result.ok, "build %s: %s" % [color, result.message])
	return result.value


func _link(sim: Simulation, factory_id: int, market: StringName = NEAR) -> int:
	var result := sim.make_link(factory_id, market)
	assert_true(result.ok, "link: %s" % result.message)
	return result.value


func _buy_tier(sim: Simulation) -> void:
	var result := sim.buy_transport_tier()
	assert_true(result.ok, "buy tier: %s" % result.message)


func _assert_money(sim: Simulation, expected: float) -> void:
	assert_true(sim.money().equals(BigNumber.from_float(expected)),
		"money should be %s, got %s" % [expected, sim.money().format()])


func _assert_fails(result: CommandResult, reason: CommandResult.Reason, message_part: String) -> void:
	assert_false(result.ok, "the command fails")
	assert_eq(result.reason, reason, result.message)
	assert_string_contains(result.message, message_part)


# --- Transport tiers -------------------------------------------------------------

func test_a_run_starts_with_carts_and_only_the_markets_they_reach_open() -> void:
	var sim := _sim()

	assert_eq(sim.transport_tier().id, &"cart")
	assert_eq(sim.next_transport_tier().id, &"truck")
	var markets := sim.markets()
	assert_eq(markets.map(func(m: MarketView) -> Array: return [m.id, m.remoteness, m.needed_tier, m.is_open]), [
		[NEAR, 0, &"cart", true],
		[FAR, 2, &"truck", false],
		[FARTHEST, 4, &"train", false],
	])


func test_buying_the_next_tier_costs_its_price_and_opens_the_markets_it_reaches() -> void:
	var sim := _sim()

	var result := sim.buy_transport_tier()

	assert_true(result.ok, result.message)
	assert_eq(result.value, &"truck")
	_assert_money(sim, 100 - ContentFixture.TRUCK_PRICE)
	assert_eq(sim.transport_tier().id, &"truck")
	assert_eq(sim.next_transport_tier().id, &"train")
	assert_true(sim.market(FAR).is_open)
	assert_false(sim.market(FARTHEST).is_open)


func test_tiers_are_bought_in_order() -> void:
	var sim := _sim(1000)
	_buy_tier(sim)

	_buy_tier(sim)

	assert_eq(sim.transport_tier().id, &"train")
	_assert_money(sim, 1000 - ContentFixture.TRUCK_PRICE - ContentFixture.TRAIN_PRICE)
	assert_true(sim.market(FARTHEST).is_open)
	assert_null(sim.next_transport_tier())


func test_buying_a_tier_with_too_little_money_fails_with_a_reason() -> void:
	var sim := _sim(ContentFixture.TRUCK_PRICE - 1)
	var before := sim.snapshot()

	_assert_fails(sim.buy_transport_tier(), CommandResult.Reason.NOT_ENOUGH_MONEY,
		"The truck tier costs %d" % ContentFixture.TRUCK_PRICE)

	assert_eq(sim.snapshot(), before, "nothing changes")


func test_there_is_no_tier_after_the_highest() -> void:
	var sim := _sim(1000)
	_buy_tier(sim)
	_buy_tier(sim)
	var before := sim.snapshot()

	_assert_fails(sim.buy_transport_tier(), CommandResult.Reason.NO_HIGHER_TIER, "highest transport tier (train)")

	assert_eq(sim.snapshot(), before, "nothing changes")


# --- Remoteness --------------------------------------------------------------------

func test_a_link_to_a_market_that_is_too_remote_fails_with_the_tier_it_needs() -> void:
	var sim := _sim()
	var factory_id := _build(sim)
	var before := sim.snapshot()

	_assert_fails(sim.make_link(factory_id, FAR), CommandResult.Reason.MARKET_TOO_REMOTE,
		"Farpoint is too remote for carts: it needs trucks.")
	_assert_fails(sim.make_link(factory_id, FARTHEST), CommandResult.Reason.MARKET_TOO_REMOTE,
		"it needs trains")

	assert_eq(sim.snapshot(), before, "nothing changes")
	assert_false(sim.has_link(factory_id, FAR))


func test_a_higher_tier_lets_a_link_go_to_a_more_remote_market() -> void:
	var sim := _sim()
	var factory_id := _build(sim)
	_buy_tier(sim)

	var link_id := _link(sim, factory_id, FAR)

	assert_eq(sim.link(link_id).vehicle, &"truck")
	_assert_fails(sim.make_link(factory_id, FARTHEST), CommandResult.Reason.MARKET_TOO_REMOTE,
		"too remote for trucks: it needs trains")


func test_a_remote_market_sells_like_any_other() -> void:
	var sim := _sim()
	var factory_id := _build(sim)
	_buy_tier(sim)
	var link_id := _link(sim, factory_id, FAR)
	sim.tick(3000)

	assert_eq(sim.start_shipment(link_id).value, 3)
	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)

	_assert_money(sim, 100 - 10 - ContentFixture.TRUCK_PRICE - ContentFixture.TRUCK_SHIPMENT_COST
		+ 3 * ContentFixture.PRICE)


# --- Vehicles ------------------------------------------------------------------------

func test_after_a_tier_purchase_current_links_keep_their_vehicles() -> void:
	var sim := _sim()
	var link_id := _link(sim, _build(sim))

	_buy_tier(sim)

	var link := sim.link(link_id)
	assert_eq(link.vehicle, &"cart")
	assert_eq(link.transit_time_ms, ContentFixture.TRANSIT_TIME_MS)
	assert_true(link.shipment_cost.equals(BigNumber.from_int(ContentFixture.SHIPMENT_COST)))


func test_a_new_link_uses_the_tier_the_player_has() -> void:
	var sim := _sim()
	var red := _build(sim, &"red")
	var cart_link := _link(sim, red)
	_buy_tier(sim)
	var blue := _build(sim, &"blue")

	var truck_link := _link(sim, blue)

	assert_eq(sim.link(cart_link).vehicle, &"cart")
	assert_eq(sim.link(truck_link).vehicle, &"truck")
	assert_eq(sim.link(truck_link).transit_time_ms, ContentFixture.TRUCK_TRANSIT_TIME_MS)


func test_a_new_link_to_a_factory_uses_the_tier_the_player_has() -> void:
	var sim := _sim()
	var yellow := _build(sim, &"yellow")
	var green := _build(sim, &"green")
	_buy_tier(sim)

	var result := sim.make_factory_link(yellow, green)

	assert_true(result.ok, result.message)
	assert_eq(sim.link(result.value).vehicle, &"truck")


func test_upgrading_a_vehicle_changes_its_transit_time_and_shipment_cost() -> void:
	var sim := _sim()
	var link_id := _link(sim, _build(sim))
	_buy_tier(sim)

	var result := sim.upgrade_vehicle(link_id)

	assert_true(result.ok, result.message)
	assert_eq(result.value, &"truck")
	_assert_money(sim, 100 - 10 - ContentFixture.TRUCK_PRICE - ContentFixture.TRUCK_UPGRADE_COST)
	var link := sim.link(link_id)
	assert_eq(link.vehicle, &"truck")
	assert_eq(link.transit_time_ms, ContentFixture.TRUCK_TRANSIT_TIME_MS)
	assert_true(link.shipment_cost.equals(BigNumber.from_int(ContentFixture.TRUCK_SHIPMENT_COST)))


func test_a_shipment_after_an_upgrade_uses_the_new_vehicle() -> void:
	var sim := _sim()
	var link_id := _link(sim, _build(sim))
	_buy_tier(sim)
	sim.upgrade_vehicle(link_id)
	sim.tick(4000)
	var before := sim.money()

	assert_eq(sim.start_shipment(link_id).value, 4)

	assert_true(sim.money().equals(before.sub(BigNumber.from_int(ContentFixture.TRUCK_SHIPMENT_COST))),
		"the shipment costs the truck shipment cost")
	assert_eq(sim.link(link_id).shipments_in_transit[0].remaining_ms, ContentFixture.TRUCK_TRANSIT_TIME_MS)


func test_an_upgrade_does_not_change_shipments_in_transit() -> void:
	var sim := _sim()
	var link_id := _link(sim, _build(sim))
	sim.tick(2000)
	sim.start_shipment(link_id)
	_buy_tier(sim)
	sim.tick(1000)

	sim.upgrade_vehicle(link_id)

	assert_eq(sim.link(link_id).shipments_in_transit[0].remaining_ms, ContentFixture.TRANSIT_TIME_MS - 1000)


func test_an_upgrade_goes_straight_to_the_tier_the_player_has() -> void:
	var sim := _sim(1000)
	var link_id := _link(sim, _build(sim))
	_buy_tier(sim)
	_buy_tier(sim)
	var before := sim.money()

	var result := sim.upgrade_vehicle(link_id)

	assert_true(result.ok, result.message)
	assert_eq(sim.link(link_id).vehicle, &"train")
	assert_true(sim.money().equals(before.sub(BigNumber.from_int(ContentFixture.TRAIN_UPGRADE_COST))),
		"it costs the train upgrade cost only")


func test_an_automatic_link_keeps_its_next_start_and_then_uses_the_new_transit_time() -> void:
	var sim := _sim(1000)
	var link_id := _link(sim, _build(sim))
	sim.buy_automatic_transport(link_id)
	sim.tick(1000)
	assert_eq(sim.link(link_id).next_automatic_in_ms, ContentFixture.TRANSIT_TIME_MS - 1000)
	_buy_tier(sim)

	sim.upgrade_vehicle(link_id)

	assert_eq(sim.link(link_id).next_automatic_in_ms, ContentFixture.TRANSIT_TIME_MS - 1000,
		"the next start keeps its time")
	# The start is due at the end of this tick, so it happens in the next one.
	sim.tick(ContentFixture.TRANSIT_TIME_MS - 1000 + 1)
	assert_eq(sim.link(link_id).next_automatic_in_ms, ContentFixture.TRUCK_TRANSIT_TIME_MS - 1,
		"the start after it comes one truck transit time later")


func test_upgrading_a_vehicle_that_is_already_the_current_tier_fails() -> void:
	var sim := _sim()
	var link_id := _link(sim, _build(sim))
	var before := sim.snapshot()

	_assert_fails(sim.upgrade_vehicle(link_id), CommandResult.Reason.VEHICLE_IS_CURRENT,
		"already uses carts")

	assert_eq(sim.snapshot(), before, "nothing changes")


func test_upgrading_a_vehicle_with_too_little_money_fails_with_a_reason() -> void:
	var sim := _sim(10 + ContentFixture.TRUCK_PRICE + ContentFixture.TRUCK_UPGRADE_COST - 1)
	var link_id := _link(sim, _build(sim))
	_buy_tier(sim)
	var before := sim.snapshot()

	_assert_fails(sim.upgrade_vehicle(link_id), CommandResult.Reason.NOT_ENOUGH_MONEY,
		"A truck for link #%d costs %d" % [link_id, ContentFixture.TRUCK_UPGRADE_COST])

	assert_eq(sim.snapshot(), before, "nothing changes")
	assert_eq(sim.link(link_id).vehicle, &"cart")


func test_upgrading_the_vehicle_of_an_unknown_link_fails() -> void:
	var sim := _sim()
	_buy_tier(sim)

	_assert_fails(sim.upgrade_vehicle(42), CommandResult.Reason.UNKNOWN_LINK, "There is no link #42.")


func test_a_prestige_starts_the_new_run_with_carts() -> void:
	var sim := _sim(1000)
	_link(sim, _build(sim))
	_buy_tier(sim)
	assert_true(sim.buy_prism().ok)

	assert_true(sim.prestige().ok)

	assert_eq(sim.transport_tier().id, &"cart")
	assert_eq(sim.next_transport_tier().id, &"truck")
	assert_false(sim.market(FAR).is_open, "farpoint closes again")
	assert_string_contains(", ".join(sim.prestige_preview().clears), "Transport tier")


# --- Warehouses ----------------------------------------------------------------------

func test_links_to_and_from_a_warehouse_use_the_tier_the_player_has() -> void:
	var sim := _sim(1000)
	var red := _build(sim)
	var warehouse: int = sim.build_warehouse(&"red").value
	var cart_in: int = sim.link_factory_to_warehouse(red, warehouse).value
	_buy_tier(sim)

	var truck_out := sim.link_warehouse_to_market(warehouse, FAR)

	assert_true(truck_out.ok, truck_out.message)
	assert_eq(sim.link(cart_in).vehicle, &"cart", "the link keeps its cart")
	assert_eq(sim.link(truck_out.value).vehicle, &"truck")
	assert_true(sim.upgrade_vehicle(cart_in).ok)
	assert_eq(sim.link(cart_in).transit_time_ms, ContentFixture.TRUCK_TRANSIT_TIME_MS)


func test_a_link_from_a_warehouse_to_a_market_that_is_too_remote_fails() -> void:
	var sim := _sim(1000)
	var warehouse: int = sim.build_warehouse(&"red").value
	var before := sim.snapshot()

	_assert_fails(sim.link_warehouse_to_market(warehouse, FAR), CommandResult.Reason.MARKET_TOO_REMOTE,
		"Farpoint is too remote for carts: it needs trucks.")

	assert_eq(sim.snapshot(), before, "nothing changes")
