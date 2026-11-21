extends GutTest
## The save: a versioned, serialized form of the core state (see ADR-0009).


## A game where every part of the core state has a value that is not its
## default. When you add core state, give it a non-default value here, so that
## the round-trip tests fail if save or load forgets it.
func _rich_game() -> Simulation:
	var sim := Simulation.new(_content(), 77)
	sim.build_factory(&"red")
	sim.tick(1234)
	sim.build_factory(&"blue")
	sim.add_production_line(2)
	sim.make_link(1, &"millbrook")
	sim.make_link(2, &"millbrook")
	sim.buy_automatic_transport(2)
	sim.tick(5000)
	sim.start_shipment(1)
	sim.start_shipment(2)
	sim.build_factory(&"yellow")
	sim.tick(333)
	sim.tick(1400)
	sim.start_shipment(1)
	# The first two shipments sell, and two are still in transit on link 1.
	# Link 2 is automatic and has shipped.
	sim.tick(3500)
	sim.start_shipment(1)
	# A mixed factory, with yellow widgets in its input bay and blue widgets on
	# their way, and its own progress.
	# The blue factory #2 ships to the market by itself, so a second blue
	# factory feeds the green factory.
	assert_true(sim.build_factory(&"green").ok)
	assert_true(sim.build_factory(&"blue").ok)
	sim.make_factory_link(3, 4)
	sim.make_factory_link(5, 4)
	# A red warehouse, fed by the red factory #1, that holds widgets and has
	# widgets on their way to it, and a link from it to the market.
	assert_true(sim.build_warehouse(&"red").ok)
	sim.link_factory_to_warehouse(1, 1)
	sim.link_warehouse_to_market(1, &"millbrook")
	sim.add_production_line(4)
	sim.start_shipment(3)
	sim.tick(1400)
	sim.start_shipment(5)
	sim.tick(2100)
	sim.start_shipment(5)
	sim.tick(1500)
	sim.start_shipment(4)
	sim.start_shipment(1)
	sim.tick(1400)
	sim.start_shipment(1)
	# The sales saturate red and blue in millbrook, and use some of its
	# capacity in this period.
	sim.buy_prism()
	sim.buy_prism()
	assert_true(sim.make_community_investment(&"millbrook", MarketView.Investment.POPULATION).ok)
	assert_true(sim.make_community_investment(&"millbrook", MarketView.Investment.INCOME).ok)
	assert_true(sim.make_community_investment(&"millbrook", MarketView.Investment.INCOME).ok)
	# Trucks, with link 1 (to millbrook) and link 5 (to the warehouse) moved
	# onto them while link 1 has shipments in transit, and a new link to a
	# market that only trucks reach. Link 2 keeps its cart.
	assert_true(sim.buy_transport_tier().ok)
	assert_true(sim.upgrade_vehicle(1).ok)
	assert_true(sim.upgrade_vehicle(5).ok)
	assert_true(sim.make_link(1, &"farpoint").ok)
	_add_research(sim)
	# Again blue widgets on their way to the green factory, red widgets on
	# their way to the warehouse, two shipments on link 1 to millbrook, and
	# green widgets on their way to the lab.
	sim.tick(1400)
	assert_true(sim.start_shipment(1).ok)
	# That shipment sells, so red is saturated again.
	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)
	assert_true(sim.start_shipment(1).ok)
	sim.tick(700)
	var to_warehouse := sim.start_shipment(5)
	assert_true(to_warehouse.ok, to_warehouse.message)
	sim.tick(700)
	assert_true(sim.start_shipment(1).ok)
	var blue := sim.start_shipment(4)
	assert_true(blue.ok, blue.message)
	var green := sim.start_shipment(11)
	assert_true(green.ok, green.message)
	# A split of blue factory #5 between the green factory (link 4) and the lab
	# (link 10), and its first automatic starts.
	assert_true(sim.buy_automatic_transport(4).ok)
	assert_true(sim.buy_automatic_transport(10).ok)
	var split := sim.set_split({4: 60, 10: 40})
	assert_true(split.ok, split.message)
	sim.tick(1)
	return sim


## A lab with links from four factories (links 8 to 11, by trucks), complete
## research (earth_tones), progress on research that is not selected
## (warm_mixes), the selected research (cool_mixes), and yellow widgets in the
## lab stock.
func _add_research(sim: Simulation) -> void:
	var lab: int = sim.build_lab().value
	var links: Array[int] = []
	for factory_id in [1, 3, 5, 4]:
		var result := sim.make_lab_link(factory_id, lab)
		assert_true(result.ok, result.message)
		links.append(result.value)
	# The factories make widgets for the lab, and yellow widgets go to the
	# green factory, where they wait for blue.
	var yellow_to_green := sim.start_shipment(3)
	assert_true(yellow_to_green.ok, yellow_to_green.message)
	sim.tick(2100)
	assert_true(sim.select_research(&"earth_tones").ok)
	for link in links.slice(0, 3):
		var result := sim.start_shipment(link)
		assert_true(result.ok, result.message)
	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)
	assert_eq(sim.research_item(&"earth_tones").status, ResearchView.Status.COMPLETE)
	assert_true(sim.select_research(&"warm_mixes").ok)
	var red := sim.start_shipment(links[0])
	assert_true(red.ok, red.message)
	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)
	var yellow := sim.start_shipment(links[1])
	assert_true(yellow.ok, yellow.message)
	assert_true(sim.select_research(&"cool_mixes").ok)
	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)


## The content of the rich game, with the mixed colors, drift, saturation,
## demand events, a second market that only trucks reach, money for all of
## it, and the research of [method ContentFixture.research_data] and
## warm_mixes (2 red and 1 yellow; unlocks brown). An event starts each 5 to
## 10 s, so a save of an old version that a test ticks for less than 5 s after
## its load has no event yet.
func _content() -> Content:
	var colors := ContentFixture.mixed_colors_data()
	var research := ContentFixture.research_data(colors)
	research.research.append({"id": "warm_mixes", "name": "Warm mixes",
		"cost": {"red": 2, "yellow": 1}, "unlocks": {"colors": ["brown"]}})
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(700, 6, ContentFixture.demand_overrides().merged({"starting_money": 1000})),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, ["millbrook", "farpoint"],
			ContentFixture.POPULATION, ContentFixture.INCOME, [0, 2]),
		ContentFixture.transport_data(), ContentFixture.demand_events_data(), research))


## Content with demand that stays at 1, for the saves of old versions, whose
## tests check money from sales at the base price.
func _flat_content() -> Content:
	return ContentFixture.make_mixed(700, 6)


func _load(text: String, steps: Array[Callable] = SaveCodec.migrations(),
		content: Content = _content()) -> LoadResult:
	return SaveCodec.decode(content, text, steps)


func test_the_rich_game_has_every_kind_of_state() -> void:
	# The round-trip tests below cover only what the rich game has.
	var sim := _rich_game()
	var green := sim.factory(4)
	assert_eq(green.color, &"green")
	assert_gt(green.input_bays[0].count, 0, "yellow widgets in the green input bay")
	assert_gt(green.input_bays[1].in_transit, 0, "blue widgets on their way to the green factory")
	assert_eq(sim.link(3).destination_kind, LinkView.Destination.FACTORY)
	assert_eq(sim.link(1).destination_kind, LinkView.Destination.MARKET)
	assert_eq(sim.link(1).shipments_in_transit.size(), 2, "two shipments to a market")
	assert_gt(sim.demand_events().size(), 0, "active demand events")
	var millbrook := sim.market(&"millbrook")
	assert_gt(millbrook.capacity_used, 0, "sales in this period")
	assert_gt(millbrook.capacity_in_transit, 0, "widgets on their way to the market")
	assert_gt(millbrook.population, ContentFixture.POPULATION, "a community investment for population")
	assert_gt(millbrook.income, ContentFixture.INCOME, "community investments for income")
	var warehouse := sim.warehouse(1)
	assert_gt(warehouse.count, 0, "widgets in the warehouse")
	assert_gt(warehouse.in_transit, 0, "widgets on their way to the warehouse")
	assert_gt(warehouse.inflow_per_minute, 0, "widgets started to the warehouse")
	assert_eq(sim.link(5).destination_kind, LinkView.Destination.WAREHOUSE)
	assert_eq(sim.link(6).source_kind, LinkView.Source.WAREHOUSE)
	assert_eq(sim.transport_tier().id, &"truck")
	assert_eq([sim.link(1).vehicle, sim.link(2).vehicle, sim.link(5).vehicle, sim.link(7).vehicle],
		[&"truck", &"cart", &"truck", &"truck"])
	assert_eq(sim.link(7).destination_market_id, &"farpoint")
	assert_eq(sim.labs(), [1] as Array[int])
	assert_eq([sim.link(11).destination_kind, sim.link(11).vehicle], [LinkView.Destination.LAB, &"truck"])
	assert_gt(sim.link(11).shipments_in_transit.size(), 0, "green widgets on their way to the lab")
	assert_eq(sim.research_item(&"earth_tones").status, ResearchView.Status.COMPLETE)
	assert_eq(sim.research_item(&"warm_mixes").paid, {&"red": 2, &"yellow": 0} as Dictionary[StringName, int],
		"progress on research that is not selected")
	assert_eq(sim.selected_research(), &"cool_mixes")
	assert_eq(sim.lab_stock(), {&"yellow": 1} as Dictionary[StringName, int])
	assert_eq(sim.splits().size(), 1, "a split")
	var split := sim.splits()[0]
	assert_eq(split.shares, {4: 60, 10: 40})
	assert_gt(split.shipped[4] + split.shipped[10], 0, "the split counts shipped widgets")


func test_save_then_load_gives_the_same_state() -> void:
	var sim := _rich_game()

	var result := _load(SaveCodec.encode(sim))

	assert_true(result.ok, result.message)
	var loaded := result.simulation
	assert_eq(loaded.time_ms(), sim.time_ms())
	assert_true(loaded.money().equals(sim.money()), "money %s" % loaded.money())
	assert_eq(loaded.factories().size(), 5)
	for i in sim.factories().size():
		var want := sim.factories()[i]
		var got := loaded.factories()[i]
		assert_eq(got.id, want.id)
		assert_eq(got.color, want.color)
		assert_eq(got.size, want.size)
		assert_eq(got.output_bay_count, want.output_bay_count)
		assert_eq(got.status, want.status)
		assert_eq(got.input_bays.map(func(b: InputBayView) -> Array: return [b.color, b.count, b.in_transit]),
			want.input_bays.map(func(b: InputBayView) -> Array: return [b.color, b.count, b.in_transit]))
	assert_eq(loaded.links().size(), 11)
	var want_warehouse := sim.warehouse(1)
	var got_warehouse := loaded.warehouse(1)
	assert_eq([got_warehouse.color, got_warehouse.count, got_warehouse.in_transit,
			got_warehouse.inflow_per_minute, got_warehouse.outflow_per_minute],
		[want_warehouse.color, want_warehouse.count, want_warehouse.in_transit,
			want_warehouse.inflow_per_minute, want_warehouse.outflow_per_minute])
	assert_eq([loaded.link(6).source_kind, loaded.link(6).source_warehouse_id], [LinkView.Source.WAREHOUSE, 1])
	assert_eq([loaded.link(5).destination_kind, loaded.link(5).destination_warehouse_id],
		[LinkView.Destination.WAREHOUSE, 1])
	assert_eq(loaded.transport_tier().id, &"truck")
	for view in sim.links():
		var got := loaded.link(view.id)
		assert_eq([got.vehicle, got.transit_time_ms], [view.vehicle, view.transit_time_ms], "link %d" % view.id)
		assert_true(got.shipment_cost.equals(view.shipment_cost))
	assert_true(loaded.market(&"farpoint").is_open, "trucks reach farpoint")
	assert_eq([loaded.link(3).destination_kind, loaded.link(3).destination_factory_id],
		[LinkView.Destination.FACTORY, 4])
	var shipments := loaded.link(1).shipments_in_transit
	assert_eq(shipments.size(), sim.link(1).shipments_in_transit.size(), "shipments in transit are kept")
	assert_eq(shipments.map(func(v: ShipmentView) -> int: return v.remaining_ms),
		sim.link(1).shipments_in_transit.map(func(v: ShipmentView) -> int: return v.remaining_ms))
	assert_eq(loaded.link(2).automatic, LinkView.Automatic.SHIPPED)
	assert_eq(loaded.link(2).next_automatic_in_ms, sim.link(2).next_automatic_in_ms)
	assert_eq(loaded.link(1).widgets_per_minute, sim.link(1).widgets_per_minute)
	assert_eq(sim.snapshot().saturation.size(), 2, "the rich game has saturation")
	for view in sim.markets():
		var got := loaded.market(view.id)
		assert_eq(got.demands, view.demands, "demand in %s" % view.id)
		for color in view.prices:
			assert_true(got.price(color).equals(view.price(color)), "price of %s" % color)
		assert_eq([got.population, got.income, got.capacity, got.capacity_used, got.capacity_in_transit],
			[view.population, view.income, view.capacity, view.capacity_used, view.capacity_in_transit])
		for goal: MarketView.Investment in MarketView.Investment.values():
			assert_true(got.investment_cost(goal).equals(view.investment_cost(goal)), "investment cost")
	assert_eq(sim.prisms().owned, 2, "the rich game has prisms")
	assert_eq(loaded.prisms().owned, 2)
	assert_eq(loaded.prisms().total_bought, 2)
	assert_true(loaded.prisms().next_price.equals(sim.prisms().next_price))
	var event_fields := func(v: DemandEventView) -> Array: return [v.id, v.started_at_ms, v.remaining_ms]
	assert_eq(loaded.demand_events().map(event_fields), sim.demand_events().map(event_fields),
		"active demand events are kept")
	assert_eq(loaded.labs(), sim.labs())
	assert_eq([loaded.link(8).destination_kind, loaded.link(8).destination_lab_id], [LinkView.Destination.LAB, 1])
	for want in sim.research():
		var got := loaded.research_item(want.id)
		assert_eq([got.status, got.paid, got.in_transit], [want.status, want.paid, want.in_transit],
			"research %s" % want.id)
	assert_eq(loaded.selected_research(), &"cool_mixes")
	assert_eq(loaded.lab_stock(), sim.lab_stock())
	assert_true(loaded.is_color_unlocked(&"brown"), "complete research keeps its unlocks")
	var split := loaded.splits()[0]
	assert_eq([split.source_factory_id, split.color, split.shares, split.shipped],
		[5, &"blue", sim.splits()[0].shares, sim.splits()[0].shipped])
	assert_eq(loaded.snapshot(), sim.snapshot())


func test_the_loaded_game_plays_on_the_same_as_the_saved_game() -> void:
	var sim := _rich_game()
	var loaded := _load(SaveCodec.encode(sim)).simulation

	for game in [sim, loaded]:
		game.build_factory(&"red")
		game.make_link(3, &"millbrook")
		game.tick(98_765)
		game.start_shipment(1)
		game.start_shipment(4)
		game.start_shipment(6)
		game.start_shipment(11)
		game.select_research(&"warm_mixes")
		game.start_shipment(8)
		game.tick(7000)

	assert_eq(loaded.snapshot(), sim.snapshot())


func test_save_then_load_after_a_prestige_gives_the_same_state() -> void:
	var sim := _rich_game()
	assert_true(sim.prestige().ok, "the rich game has prisms")
	sim.build_factory(&"red")
	sim.tick(2500)

	var result := _load(SaveCodec.encode(sim))

	assert_true(result.ok, result.message)
	var loaded := result.simulation
	assert_eq(loaded.prisms().owned, 2)
	assert_eq(loaded.prisms().total_bought, 2)
	assert_eq(loaded.factories().size(), 1)
	assert_eq(loaded.labs(), [] as Array[int], "a prestige clears the labs")
	assert_eq(loaded.selected_research(), &"")
	assert_eq(loaded.lab_stock(), {} as Dictionary[StringName, int])
	assert_false(loaded.is_color_unlocked(&"brown"), "a prestige clears complete research")
	assert_eq(loaded.snapshot(), sim.snapshot())
	for game in [sim, loaded]:
		game.make_link(1, &"millbrook")
		game.tick(12_345)
		game.start_shipment(1)
		game.prestige()
	assert_eq(loaded.snapshot(), sim.snapshot(), "the loaded game plays on and prestiges the same")


func test_the_save_has_a_version_number() -> void:
	var data: Dictionary = JSON.parse_string(SaveCodec.encode(_rich_game()))

	assert_eq(data.format, SaveCodec.FORMAT)
	assert_eq(int(data.version), SaveCodec.current_version())
	assert_eq(SaveCodec.current_version(), SaveCodec.migrations().size() + 1)


# --- Damaged saves -------------------------------------------------------------

## Loads [param text] and checks that it fails with [param reason] and a message
## that has [param message_part], and that the current game does not change.
func _assert_load_fails(text: String, reason: LoadResult.Reason, message_part: String) -> void:
	var current := _rich_game()
	var before := current.snapshot()

	var result := _load(text)

	assert_false(result.ok, "the load fails")
	assert_eq(result.reason, reason, result.message)
	assert_string_contains(result.message, message_part)
	assert_null(result.simulation)
	assert_eq(current.snapshot(), before, "the current game does not change")


## The save of the rich game as parsed JSON, to damage in tests.
func _save_data() -> Dictionary:
	return JSON.parse_string(SaveCodec.encode(_rich_game()))


func test_a_cut_off_save_fails_as_not_json() -> void:
	var text := SaveCodec.encode(_rich_game())
	_assert_load_fails(text.substr(0, text.length() / 2), LoadResult.Reason.NOT_JSON, "not valid JSON")


func test_an_empty_save_fails_as_not_json() -> void:
	_assert_load_fails("", LoadResult.Reason.NOT_JSON, "not valid JSON")


func test_json_that_is_not_a_save_fails() -> void:
	_assert_load_fails("[1, 2, 3]", LoadResult.Reason.NOT_A_SAVE, "not a save")
	_assert_load_fails("{\"version\": 1, \"state\": {}}", LoadResult.Reason.NOT_A_SAVE, "not a save")


func test_a_save_with_no_valid_version_fails() -> void:
	var data := _save_data()
	data.erase("version")
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.BAD_VERSION, "save.version: is missing")
	data.version = 0
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.BAD_VERSION, "save.version: must be from 1")
	data.version = "one"
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.BAD_VERSION, "must be a whole number")


func test_a_save_from_a_newer_game_fails() -> void:
	var data := _save_data()
	data.version = SaveCodec.current_version() + 1
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.NEWER_VERSION, "newer version")


func test_a_save_with_no_state_fails() -> void:
	var data := _save_data()
	data.erase("state")
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, "state: must be an object")


func test_a_negative_count_fails() -> void:
	var data := _save_data()
	data.state.factories[1].output_bay_count = -3
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.factories[1].output_bay_count: must be from 0")


func test_a_fraction_where_a_whole_number_must_be_fails() -> void:
	var data := _save_data()
	data.state.time_ms = 12.5
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.time_ms: must be a whole number, but it is 12.5")


func test_a_color_that_is_not_in_the_content_fails() -> void:
	var data := _save_data()
	data.state.factories[0].color = "magenta"
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.factories[0].color: there is no color \"magenta\"")


func test_two_factories_with_the_same_id_fail() -> void:
	var data := _save_data()
	data.state.factories[2].id = data.state.factories[0].id
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.factories[2].id: is used by more than one factory")


func test_a_factory_id_that_is_not_below_the_next_id_fails() -> void:
	var data := _save_data()
	data.state.factories[2].id = data.state.next_factory_id
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.factories[2].id: must be less than next_factory_id")


func test_a_factory_with_no_production_lines_fails() -> void:
	var data := _save_data()
	data.state.factories[0].size = 0
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.factories[0].size: must be from 1")


func test_negative_money_fails() -> void:
	var data := _save_data()
	data.state.money = [-5.0, 2]
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, "state.money: cannot be negative")


func test_money_with_a_mantissa_that_is_not_normalized_fails() -> void:
	var data := _save_data()
	data.state.money = [45.0, 1]
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.money[0]: must be a mantissa of 0 or from 1 to less than 10, but it is 45")


func test_large_money_keeps_its_value() -> void:
	var data := _save_data()
	data.state.money = [1.2345678901234, 123_456_789]

	var result := _load(JSON.stringify(data))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.money().to_data(), [1.2345678901234, 123_456_789])


## [param change] gets the first link of the saved state, which has shipments.
func _assert_link_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state.links[0])
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_a_link_to_an_unknown_market_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.destination_market_id = "atlantis",
		"state.links[0].destination_market_id: there is no market \"atlantis\"")


func test_a_link_with_an_unknown_vehicle_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.vehicle = "rocket",
		"state.links[0].vehicle: there is no transport tier \"rocket\"")


func test_a_link_from_a_missing_factory_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.source_factory_id = 9,
		"state.links[0].source_factory_id: there is no factory #9")


func test_a_link_of_another_color_than_its_factory_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.color = "blue",
		"state.links[0].color: must be the color of factory #1")


func test_two_links_on_the_same_factory_and_market_fail() -> void:
	var data := _save_data()
	data.state.links[1].source_factory_id = 1
	data.state.links[1].color = "red"
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.links[1].destination_market_id: factory #1 has more than one link")


func test_a_link_id_that_is_not_below_the_next_id_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.id = 12,
		"state.links[0].id: must be less than next_link_id (12)")


func test_two_shipments_with_the_same_id_fail() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.shipments[1].id = link.shipments[0].id,
		"state.links[0].shipments[1].id: is used by more than one shipment")


func test_an_empty_shipment_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.shipments[0].count = 0,
		"state.links[0].shipments[0].count: must be from 1")


func test_a_shipment_that_has_already_arrived_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.shipments[0].arrives_at_ms = 0,
		"state.links[0].shipments[0].arrives_at_ms: must be after time_ms")


func test_an_unknown_automatic_status_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.automatic_status = "flying",
		"state.links[0].automatic_status: must be one of manual, ready, shipped")


func test_a_manual_link_with_a_next_automatic_start_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.next_automatic_ms = 5,
		"state.links[0].next_automatic_ms: must be 0 on a manual link")


func test_an_automatic_start_before_now_fails() -> void:
	var data := _save_data()
	data.state.links[1].next_automatic_ms = 0
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.links[1].next_automatic_ms: must not be before time_ms")


func test_a_recent_start_out_of_the_throughput_window_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.recent_starts[0].started_at_ms = 99_999_999,
		"state.links[0].recent_starts[0].started_at_ms: must be in the throughput window")


func test_recent_starts_out_of_order_fail() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.recent_starts[1].started_at_ms = 0,
		"state.links[0].recent_starts[1].started_at_ms: must not be before the start before it")


func test_a_drift_key_that_is_not_a_u32_fails() -> void:
	var data := _save_data()
	data.state.drift_key = 4294967296
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.drift_key: must be from 0 to 4294967295")


## [param change] gets the first saturation entry of the saved state.
func _assert_saturation_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state.saturation[0])
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_saturation_in_an_unknown_market_fails() -> void:
	_assert_saturation_change_fails(func(entry: Dictionary) -> void: entry.market_id = "atlantis",
		"state.saturation[0].market_id: there is no market \"atlantis\"")


func test_saturation_of_an_unknown_color_fails() -> void:
	_assert_saturation_change_fails(func(entry: Dictionary) -> void: entry.color = "magenta",
		"state.saturation[0].color: there is no color \"magenta\"")


func test_saturation_that_has_recovered_fails() -> void:
	var data := _save_data()
	data.state.saturation[0].saturated_until_ms = data.state.time_ms
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.saturation[0].saturated_until_ms: must be after time_ms")


func test_two_saturation_entries_for_one_color_and_market_fail() -> void:
	var data := _save_data()
	data.state.saturation[1].color = data.state.saturation[0].color
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.saturation[1].color: blue in millbrook has more than one saturation entry")


func test_more_prisms_than_prisms_bought_fails() -> void:
	var data := _save_data()
	data.state.prisms = data.state.prisms_bought + 1
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.prisms: cannot be more than prisms_bought")


func test_negative_prisms_fail() -> void:
	var data := _save_data()
	data.state.prisms_bought = -1
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, "state.prisms_bought: must be from 0")


## [param change] gets the state, which has at least one active demand event.
func _assert_demand_event_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state)
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_an_unknown_demand_event_fails() -> void:
	_assert_demand_event_change_fails(func(state: Dictionary) -> void: state.demand_events[0].event_id = "flood",
		"state.demand_events[0].event_id: there is no demand event \"flood\"")


func test_a_demand_event_that_has_ended_fails() -> void:
	_assert_demand_event_change_fails(
		func(state: Dictionary) -> void: state.demand_events[0].ends_at_ms = state.time_ms,
		"state.demand_events[0].ends_at_ms: must be after time_ms")


func test_a_demand_event_that_starts_after_now_fails() -> void:
	_assert_demand_event_change_fails(
		func(state: Dictionary) -> void: state.demand_events[0].started_at_ms = state.time_ms + 1,
		"state.demand_events[0].started_at_ms: must not be after time_ms")


func test_demand_events_out_of_start_order_fail() -> void:
	var data := _save_data()
	var events: Array = data.state.demand_events
	var event: Dictionary = events[-1].duplicate()
	event.started_at_ms -= 1
	events.append(event)
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.demand_events[%d].started_at_ms: the events must be in start order" % (events.size() - 1))


func test_a_next_demand_event_before_now_fails() -> void:
	_assert_demand_event_change_fails(
		func(state: Dictionary) -> void: state.next_demand_event_ms = state.time_ms - 1,
		"state.next_demand_event_ms: must be -1 (no start set) or not before time_ms")


func _assert_market_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state.markets)
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_an_unknown_market_fails() -> void:
	_assert_market_change_fails(func(markets: Array) -> void: markets[0].id = "nowhere",
		"state.markets[0].id: there is no market \"nowhere\"")


func test_a_market_twice_fails() -> void:
	_assert_market_change_fails(func(markets: Array) -> void: markets.append(markets[0].duplicate()),
		"state.markets[2].id: market millbrook is in the save more than once")


func test_capacity_used_over_the_capacity_fails() -> void:
	_assert_market_change_fails(func(markets: Array) -> void: markets[0].capacity_used = 5000,
		"state.markets[0].capacity_used: is more than the capacity")


func test_a_market_with_no_population_fails() -> void:
	_assert_market_change_fails(func(markets: Array) -> void: markets[0].population = 0,
		"state.markets[0].population")


func test_a_market_that_is_not_in_the_save_starts_as_at_the_start_of_a_run() -> void:
	# Such as a market that is new in the content.
	var data := _save_data()
	data.state.markets = []

	var result := _load(JSON.stringify(data))

	assert_true(result.ok, result.message)
	var market := result.simulation.market(&"millbrook")
	assert_eq([market.population, market.income, market.capacity_used],
		[ContentFixture.POPULATION, ContentFixture.INCOME, 0])


func test_a_link_of_an_unknown_kind_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.destination_kind = "moon",
		"state.links[0].destination_kind: must be one of market, factory, warehouse, lab, but it is \"moon\"")


func test_a_link_from_an_unknown_kind_of_place_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.source_kind = "moon",
		"state.links[0].source_kind: must be one of factory, warehouse, but it is \"moon\"")


# --- Damaged warehouses ----------------------------------------------------------

## [param change] gets the saved state, whose warehouse #1 is red, link 5 goes
## from red factory #1 to it, and link 6 goes from it to millbrook.
func _assert_warehouse_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state)
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_a_warehouse_of_an_unknown_color_fails() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void: state.warehouses[0].color = "magenta",
		"state.warehouses[0].color: there is no color \"magenta\"")


func test_a_warehouse_over_its_space_fails() -> void:
	_assert_warehouse_change_fails(
		func(state: Dictionary) -> void: state.warehouses[0].count = ContentFixture.WAREHOUSE_SPACE + 1,
		"state.warehouses[0].count: must be from 0 to %d" % ContentFixture.WAREHOUSE_SPACE)


func test_a_warehouse_that_would_overflow_when_its_shipments_arrive_fails() -> void:
	_assert_warehouse_change_fails(
		func(state: Dictionary) -> void: state.warehouses[0].count = ContentFixture.WAREHOUSE_SPACE,
		"state.warehouses[0].count: %d widgets are in the warehouse and on the way, but it holds %d" % [
			ContentFixture.WAREHOUSE_SPACE + _rich_game().warehouse(1).in_transit, ContentFixture.WAREHOUSE_SPACE])


func test_a_warehouse_id_that_is_not_below_the_next_id_fails() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void: state.warehouses[0].id = 2,
		"state.warehouses[0].id: must be less than next_warehouse_id (2)")


func test_two_warehouses_with_the_same_id_fail() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void:
			state.next_warehouse_id = 3
			state.warehouses.append(state.warehouses[0].duplicate()),
		"state.warehouses[1].id: is used by more than one warehouse")


func test_a_link_to_a_missing_warehouse_fails() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void: state.links[4].destination_warehouse_id = 9,
		"state.links[4].destination_warehouse_id: there is no warehouse #9")


func test_a_link_to_a_warehouse_of_another_color_fails() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void: state.warehouses[0].color = "blue",
		"state.links[4].destination_warehouse_id: warehouse #1 holds blue, not red")


func test_a_link_from_a_missing_warehouse_fails() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void: state.links[5].source_warehouse_id = 9,
		"state.links[5].source_warehouse_id: there is no warehouse #9")


func test_a_link_from_a_warehouse_of_another_color_fails() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void: state.links[5].color = "blue",
		"state.links[5].color: must be the color of warehouse #1 (red)")


func test_a_link_from_a_warehouse_to_a_warehouse_fails() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void:
			var link: Dictionary = state.links[5]
			link.erase("destination_market_id")
			link.destination_kind = "warehouse"
			link.destination_warehouse_id = 1,
		"state.links[5].destination_warehouse_id: a link cannot go from a warehouse to a warehouse")


func test_two_links_from_one_warehouse_to_one_market_fail() -> void:
	_assert_warehouse_change_fails(func(state: Dictionary) -> void:
			var copy: Dictionary = state.links[5].duplicate(true)
			copy.id = state.next_link_id
			copy.shipments = []
			state.next_link_id += 1
			state.links.append(copy),
		"state.links[11].destination_market_id: warehouse #1 has more than one link to millbrook")


## [param change] gets the link from the yellow factory to the green factory.
func _assert_factory_link_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state.links[2])
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_a_link_to_a_missing_factory_fails() -> void:
	_assert_factory_link_change_fails(func(link: Dictionary) -> void: link.destination_factory_id = 9,
		"state.links[2].destination_factory_id: there is no factory #9")


func test_a_link_to_a_factory_whose_recipe_does_not_use_its_color_fails() -> void:
	_assert_factory_link_change_fails(func(link: Dictionary) -> void: link.destination_factory_id = 1,
		"state.links[2].destination_factory_id: the recipe of factory #1 (red) does not use yellow")


func test_two_links_between_the_same_factories_fail() -> void:
	var data := _save_data()
	data.state.links[3].source_factory_id = 3
	data.state.links[3].color = "yellow"
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.links[3].destination_factory_id: factory #3 has more than one link to factory #4")


# --- Damaged labs and research ---------------------------------------------------

## Changes the save of the rich game with [param change], which gets its
## state, and checks that the load fails with [param message_part].
func _assert_state_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state)
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_a_link_to_a_missing_lab_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.links[7].destination_lab_id = 9,
		"state.links[7].destination_lab_id: there is no lab #9")


func test_two_links_between_the_same_factory_and_lab_fail() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void:
		state.links[8].source_factory_id = 1
		state.links[8].color = "red",
		"state.links[8].destination_lab_id: factory #1 has more than one link to lab #1")


func test_two_labs_with_the_same_id_fail() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.labs.append({"id": 1}),
		"state.labs[1].id: is used by more than one lab")


func test_a_lab_id_that_is_not_below_the_next_id_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.next_lab_id = 1,
		"state.labs[0].id: must be less than next_lab_id (1)")


func test_unknown_selected_research_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.selected_research = "alchemy",
		"state.selected_research: there is no research \"alchemy\"")


func test_selected_research_that_is_complete_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.selected_research = "earth_tones",
		"state.selected_research: earth_tones is complete")


func test_unknown_complete_research_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.completed_research.append("alchemy"),
		"state.completed_research: there is no research \"alchemy\"")


func test_complete_research_before_the_research_it_requires_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void:
		state.completed_research = ["cool_mixes", "earth_tones"]
		state.selected_research = "",
		"state.completed_research: cool_mixes comes before research that it requires")


func test_progress_on_unknown_research_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.research_progress[0].research = "alchemy",
		"state.research_progress[0].research: there is no research \"alchemy\"")


func test_progress_on_complete_research_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.research_progress[0].research = "earth_tones",
		"state.research_progress[0].research: earth_tones is complete")


func test_progress_over_the_cost_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.research_progress[0].paid[0].count = 3,
		"state.research_progress[0].paid[0].count: must be from 0 to 2")


func test_progress_with_the_full_cost_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.research_progress[0].paid[1].count = 1,
		"state.research_progress[0].paid: warm_mixes has its full cost, so it must be complete")


func test_progress_with_a_color_missing_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.research_progress[0].paid.pop_back(),
		"state.research_progress[0].paid: there is no entry for yellow")


func test_stock_of_an_unknown_color_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.lab_stock[0].color = "teal",
		"state.lab_stock[0].color: there is no color \"teal\"")


func test_stock_that_the_selected_research_needs_fails() -> void:
	_assert_state_change_fails(func(state: Dictionary) -> void: state.lab_stock[0].color = "green",
		"state.lab_stock: green is in the stock, but cool_mixes still needs it")


## [param change] gets the input bays of the green factory: yellow, then blue.
func _assert_input_bay_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state.factories[3].input_bays)
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_an_input_bay_for_a_color_that_is_not_in_the_recipe_fails() -> void:
	_assert_input_bay_change_fails(func(bays: Array) -> void: bays[1].color = "red",
		"state.factories[3].input_bays[1].color: red is not an input of green")


func test_two_input_bays_for_one_color_fail() -> void:
	_assert_input_bay_change_fails(func(bays: Array) -> void: bays.append(bays[0].duplicate()),
		"state.factories[3].input_bays[2].color: yellow has more than one input bay")


func test_a_missing_input_bay_fails() -> void:
	_assert_input_bay_change_fails(func(bays: Array) -> void: bays.remove_at(1),
		"state.factories[3].input_bays: there is no input bay for blue")


func test_an_input_bay_on_a_base_factory_fails() -> void:
	var data := _save_data()
	data.state.factories[0].input_bays = [{"color": "blue", "count": 1}]
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.factories[0].input_bays[0].color: blue is not an input of red")


func test_an_input_bay_over_its_capacity_fails() -> void:
	_assert_input_bay_change_fails(func(bays: Array) -> void: bays[0].count = ContentFixture.INPUT_BAY_CAPACITY + 1,
		"state.factories[3].input_bays[0].count: must be from 0 to %d" % ContentFixture.INPUT_BAY_CAPACITY)


func test_an_input_bay_that_would_overflow_when_its_shipments_arrive_fails() -> void:
	_assert_input_bay_change_fails(func(bays: Array) -> void: bays[1].count = ContentFixture.INPUT_BAY_CAPACITY,
		"state.factories[3].input_bays: 17 blue widgets are in the bay and on the way, but the bay holds 10")


## [param change] gets the links of the saved state. Links 4 and 10 (at
## indexes 3 and 9) share the split of blue factory #5.
func _assert_split_change_fails(change: Callable, message_part: String) -> void:
	var data := _save_data()
	change.call(data.state.links)
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, message_part)


func test_split_percentages_that_do_not_add_up_to_100_fail() -> void:
	_assert_split_change_fails(func(links: Array) -> void: links[9].split_percent = 30,
		"state.links[3].split_percent: the split percentages of the links from this source add up to 90, not 100")


func test_a_split_on_only_some_links_of_a_source_fails() -> void:
	_assert_split_change_fails(func(links: Array) -> void:
			links[9].split_percent = -1
			links[9].split_shipped = 0,
		"state.links[3].split_percent: the links from this source must all have a split percentage, or none")


func test_a_split_percentage_over_100_fails() -> void:
	_assert_split_change_fails(func(links: Array) -> void: links[3].split_percent = 101,
		"state.links[3].split_percent: must be from -1 to 100")


func test_shipped_widgets_on_a_link_with_no_split_fail() -> void:
	_assert_split_change_fails(func(links: Array) -> void: links[0].split_shipped = 3,
		"state.links[0].split_shipped: must be 0 on a link with no split")


func test_a_split_percentage_on_a_manual_link_fails() -> void:
	_assert_split_change_fails(func(links: Array) -> void:
			links[0].split_percent = 100,
		"state.links[0].split_percent: must be 0 on a manual link")


func test_an_unknown_transport_tier_fails() -> void:
	var data := _save_data()
	data.state.transport_tier = "rocket"
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.transport_tier: there is no transport tier \"rocket\"")


func test_a_vehicle_above_the_transport_tier_fails() -> void:
	var data := _save_data()
	data.state.transport_tier = "cart"
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE,
		"state.links[0].vehicle: truck is a higher tier than the transport tier (cart)")


func test_a_random_number_state_of_all_zeros_fails() -> void:
	var data := _save_data()
	data.state.rng = [0, 0, 0, 0]
	_assert_load_fails(JSON.stringify(data), LoadResult.Reason.DAMAGED_STATE, "state.rng: cannot be all zeros")


## Each value in the state is required. This test removes each one in turn, so
## it covers new state with no change.
func test_each_missing_value_fails_with_its_path() -> void:
	for path in _value_paths(_save_data().state, []):
		var data := _save_data()
		_parent_of(data.state, path).erase(path[-1])
		var result := _load(JSON.stringify(data))
		assert_false(result.ok, "the load fails without %s" % [path])
		assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE, "%s: %s" % [path, result.message])


## Each value in the state is checked. This test sets each one in turn to an
## object, which no saved value can be, so it covers new state with no change.
func test_each_value_of_the_wrong_kind_fails_with_its_path() -> void:
	for path in _value_paths(_save_data().state, []):
		var data := _save_data()
		_parent_of(data.state, path)[path[-1]] = {"not": "a value"}
		var result := _load(JSON.stringify(data))
		assert_false(result.ok, "the load fails with an object at %s" % [path])
		assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE, "%s: %s" % [path, result.message])


## The path to each value in [param data] that is under a key, as a list of
## keys and indexes. It goes into objects and into lists of objects. An item of
## a list has no path of its own, because a list can have any length.
func _value_paths(data: Variant, prefix: Array) -> Array[Array]:
	var paths: Array[Array] = []
	if data is Dictionary:
		for key: Variant in data:
			paths.append(prefix + [key])
			paths.append_array(_value_paths(data[key], prefix + [key]))
	elif data is Array:
		for i in data.size():
			paths.append_array(_value_paths(data[i], prefix + [i]))
	return paths


## The object that holds the last key of [param path].
func _parent_of(data: Dictionary, path: Array) -> Variant:
	var parent: Variant = data
	for i in path.size() - 1:
		parent = parent[path[i]]
	return parent


func test_the_value_paths_cover_the_whole_state() -> void:
	# Checks the helper of the two tests above, so that they test something.
	var paths := _value_paths({"a": 1, "b": [{"c": 2}, {"c": 3}], "d": {"e": [4, 5]}}, [])

	assert_eq(paths, [["a"], ["b"], ["b", 0, "c"], ["b", 1, "c"], ["d"], ["d", "e"]] as Array[Array])


# --- Old versions ---------------------------------------------------------------

## A test migration: in its version 1, the state named time "clock_ms".
static func _rename_clock(state: Dictionary) -> Dictionary:
	state.time_ms = state.get("clock_ms")
	state.erase("clock_ms")
	return state


## A second test migration: version 2 had a "comment" that version 3 dropped.
static func _drop_comment(state: Dictionary) -> Dictionary:
	state.erase("comment")
	return state


func _old_save(version: int, state: Dictionary) -> String:
	return JSON.stringify({"format": SaveCodec.FORMAT, "version": version, "state": state})


func test_a_save_of_an_older_version_migrates_to_the_current_version() -> void:
	var state: Dictionary = _save_data().state
	state.clock_ms = state.time_ms
	state.erase("time_ms")
	var steps: Array[Callable] = [_rename_clock, _drop_comment]
	state.comment = "made by version 2"

	var result := _load(_old_save(1, state), steps)

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.time_ms(), _rich_game().time_ms())
	assert_eq(result.simulation.snapshot(), _rich_game().snapshot())


func test_a_migration_starts_at_the_version_of_the_save() -> void:
	var state: Dictionary = _save_data().state
	state.comment = "made by version 2"
	var steps: Array[Callable] = [_rename_clock, _drop_comment]

	var result := _load(_old_save(2, state), steps)

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.snapshot(), _rich_game().snapshot())


func test_a_migration_that_gives_damaged_state_fails() -> void:
	var state: Dictionary = _save_data().state
	var steps: Array[Callable] = [_rename_clock]

	var result := _load(_old_save(1, state), steps)

	assert_false(result.ok)
	assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE)
	assert_string_contains(result.message, "state.time_ms: must be a whole number, but it is null")


## A save of version 1, as the game wrote it. It must load in every later
## version of the game. When a change to the state adds a migration, add a save
## of the new version here too.
func test_a_version_1_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v1.json")

	var result := _load(text, SaveCodec.migrations(), _flat_content())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 6567)
	assert_eq(sim.money().format(), "90")
	var factories := sim.factories()
	assert_eq(factories.size(), 3)
	assert_eq([factories[0].id, factories[0].color, factories[0].size, factories[0].output_bay_count], [1, &"red", 1, 6])
	assert_eq([factories[1].id, factories[1].color, factories[1].size, factories[1].output_bay_count], [2, &"blue", 2, 6])
	assert_eq([factories[2].id, factories[2].color, factories[2].size, factories[2].output_bay_count], [3, &"yellow", 1, 0])
	assert_true(factories[0].is_stopped())
	assert_false(factories[2].is_stopped())
	sim.tick(367)
	assert_eq(sim.factory(3).output_bay_count, 1, "the yellow factory kept its progress")


## A save of version 2 (#3: links and shipments), as the game wrote it.
func test_a_version_2_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v2.json")

	var result := _load(text, SaveCodec.migrations(), _flat_content())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 4000)
	assert_eq(sim.money().format(), "78")
	var link := sim.link(1)
	assert_eq([link.color, link.source_factory_id, link.destination_market_id, link.vehicle],
		[&"red", 1, &"millbrook", &"cart"])
	assert_eq(link.shipments_in_transit.size(), 1)
	assert_eq([link.shipments_in_transit[0].count, link.shipments_in_transit[0].remaining_ms], [4, 4000])
	sim.tick(4000)
	assert_eq(sim.money().format(), "98", "the shipment of 4 red widgets sold for 5 each")
	assert_eq(link.destination_kind, LinkView.Destination.MARKET, "a version 2 link goes to a market")
	assert_eq(sim.factory(1).input_bays.size(), 0, "a version 2 factory is a base factory")


func test_a_version_2_save_has_manual_links_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v2.json"))

	assert_true(result.ok, result.message)
	var link := result.simulation.link(1)
	assert_false(link.is_automatic())
	assert_eq(link.widgets_per_minute, 0)
	result.simulation.tick(60_000)
	assert_eq(result.simulation.link(1).shipments_in_transit.size(), 0, "a manual link ships nothing by itself")


## A save of version 3 (#7: automatic transport and throughput), as the game
## wrote it.
func test_a_version_3_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v3.json")

	var result := _load(text, SaveCodec.migrations(), _flat_content())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 3100)
	assert_eq(sim.money().format(), "68")
	var link := sim.link(1)
	assert_eq(link.automatic, LinkView.Automatic.SHIPPED)
	assert_eq(link.next_automatic_in_ms, 4000)
	assert_eq(link.widgets_per_minute, 3)
	assert_eq([link.shipments_in_transit[0].count, link.shipments_in_transit[0].remaining_ms], [3, 4000])
	sim.tick(4001)
	assert_eq(sim.money().format(), "81", "the 3 widgets sold for 5 each, then the full bay of 6 shipped for 2")
	assert_eq(sim.link(1).widgets_per_minute, 9)
	assert_eq(sim.link(1).destination_kind, LinkView.Destination.MARKET, "a version 3 link goes to a market")


## A save of version 4 (#8: drift and saturation), as the game wrote it. The
## demand values pin drift: a change to the drift rule changes the demand of
## every saved game, so it needs a migration.
func test_a_version_4_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v4.json")

	var result := _load(text)

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 8000)
	var millbrook := sim.market(&"millbrook")
	assert_almost_eq(millbrook.demand(&"red"), 0.83980851257007, 1e-12, "drift and saturation")
	assert_almost_eq(millbrook.demand(&"yellow"), 1.13414130048789, 1e-12, "drift")
	assert_almost_eq(millbrook.demand(&"blue"), 0.85485032533109, 1e-12, "drift")
	sim.tick(4000)
	assert_eq(sim.snapshot().saturation, [], "the 4 red widgets sold at 8 s recovered at 12 s")
	assert_gt(sim.market(&"millbrook").demand(&"red"), millbrook.demand(&"red"))


func test_a_version_3_save_has_no_saturation_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v3.json"))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.snapshot().saturation, [])
	assert_eq(result.simulation.snapshot().drift_key, 0)


func test_a_version_1_save_has_no_links_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v1.json"))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.links().size(), 0)
	assert_true(result.simulation.make_link(1, &"millbrook").ok, "link ids start at 1")
	assert_eq(result.simulation.links()[0].id, 1)


## A save of version 5 (#18: prisms), as the game wrote it.
func test_a_version_5_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v5.json")

	var result := _load(text)

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.prisms().owned, 2)
	assert_eq(sim.prisms().total_bought, 2)
	assert_eq(sim.prisms().next_price.format(), "80")
	assert_eq(sim.money().format(), "30")


## A save of version 9 (#13: warehouses), as the game wrote it.
func test_a_version_9_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v9.json")

	var result := _load(text, SaveCodec.migrations(), _flat_content())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	var warehouse := sim.warehouse(1)
	assert_eq([warehouse.color, warehouse.count, warehouse.in_transit], [&"red", 4, 6])
	assert_eq([warehouse.inflow_per_minute, warehouse.outflow_per_minute], [14, 4])
	assert_eq([sim.link(1).destination_kind, sim.link(1).destination_warehouse_id],
		[LinkView.Destination.WAREHOUSE, 1])
	assert_eq([sim.link(2).source_kind, sim.link(2).source_warehouse_id], [LinkView.Source.WAREHOUSE, 1])
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	assert_eq(sim.warehouse(1).count, 10, "the widgets on their way arrived")


func test_a_version_8_save_has_no_warehouses_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v8.json"),
		SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.warehouses().size(), 0)
	for link in sim.links():
		assert_eq(link.source_kind, LinkView.Source.FACTORY, "a version 8 link starts at a factory")
	assert_eq(sim.build_warehouse(&"red").value, 1, "warehouse ids start at 1")


## A save of version 6 (#6: mixed factories, input bays, and links between
## factories), as the game wrote it.
func test_a_version_6_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v6.json")

	var result := _load(text, SaveCodec.migrations(), _flat_content())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 8100)
	assert_eq(sim.money().format(), "66")
	var green := sim.factory(3)
	assert_eq(green.color, &"green")
	assert_eq(green.input_bays.map(func(b: InputBayView) -> Array: return [b.color, b.count, b.in_transit]),
		[[&"yellow", 3, 0], [&"blue", 0, 6]])
	assert_eq(green.missing_inputs(), [&"blue"] as Array[StringName])
	var link := sim.link(2)
	assert_eq([link.destination_kind, link.destination_factory_id], [LinkView.Destination.FACTORY, 3])
	assert_eq(sim.link(3).destination_market_id, &"millbrook")
	sim.tick(4000 + 2100)
	assert_eq(sim.factory(3).output_bay_count, 3, "the blue widgets arrived and made green widgets")
	assert_eq(sim.factory(3).input_bays.map(func(b: InputBayView) -> int: return b.count), [0, 3])


## A save of version 8 (#10: population, income, community investment, and
## capacity used), as the game wrote it.
func test_a_version_8_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v8.json")

	var result := _load(text, SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 9000)
	var millbrook := sim.market(&"millbrook")
	assert_eq([millbrook.population, millbrook.income], [1100, 150])
	assert_eq([millbrook.capacity_used, millbrook.capacity_in_transit], [4, 6])
	assert_eq(millbrook.investment_cost(MarketView.Investment.POPULATION).format(), "20")
	assert_eq(millbrook.investment_cost(MarketView.Investment.INCOME).format(), "20")
	assert_eq(sim.money().format(), "111")
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	assert_eq(sim.money().format(), "178.5",
		"6 red widgets sold for 5, times 1.5 for income 150, times 1.5 for the red and blue spike")
	assert_eq(sim.market(&"millbrook").capacity_used, 10)


func test_a_version_7_save_has_markets_as_at_the_start_of_a_run_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v7.json"),
		SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var millbrook := result.simulation.market(&"millbrook")
	assert_eq([millbrook.population, millbrook.income, millbrook.capacity_used],
		[ContentFixture.POPULATION, ContentFixture.INCOME, 0])
	assert_eq(millbrook.investment_cost(MarketView.Investment.POPULATION).format(),
		str(ContentFixture.INVESTMENT_COST))


## A save of version 12 (#14: splits), as the game wrote it.
func test_a_version_12_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v12.json")

	var result := _load(text, SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	var split := sim.splits()[0]
	assert_eq([split.source_factory_id, split.color], [1, &"red"])
	assert_eq(split.shares, {1: 75, 2: 25, 3: 0})
	assert_eq(split.shipped, {1: 4, 2: 1, 3: 0})
	assert_eq(sim.link(3).split_percent, 0, "a manual link of the source gets 0%")
	sim.tick(120_000)
	# Purple has no blue widgets, so its red bay fills at 10 and the red factory
	# holds the rest of its 25%. Of 61 widgets, the market gets its 75% (45),
	# and 6 wait in the full output bay.
	assert_eq(sim.splits()[0].shipped, {1: 45, 2: 10, 3: 0})
	assert_eq(sim.factory(1).status, FactoryView.Status.OUTPUT_BAY_FULL)


func test_a_version_11_save_has_no_splits_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v11.json"),
		SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.splits().size(), 0)
	assert_eq(result.simulation.link(1).split_percent, LinkView.NO_SPLIT)


func test_a_version_4_save_has_no_prisms_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v4.json"))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.prisms().owned, 0)
	assert_eq(result.simulation.prisms().total_bought, 0)
	assert_eq(result.simulation.prisms().next_price.format(), str(ContentFixture.FIRST_PRISM_PRICE))


## A save of version 7 (#9: demand events), as the game wrote it: a red and
## blue spike started at 6.32 s and ends at 26.32 s, and the 5 red widgets that
## sold at 9 s sold at 1.5 times the base price.
func test_a_version_7_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v7.json")

	var result := _load(text, SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 12_000)
	assert_almost_eq(sim.money().to_float(), 100.0 - 10 - 2 + 5 * 5 * 1.5, 1e-9)
	var events := sim.demand_events()
	assert_eq(events.map(func(v: DemandEventView) -> Array: return [v.id, v.started_at_ms, v.remaining_ms]),
		[[&"red_blue_spike", 6320, 14_320]])
	assert_eq(sim.market(&"millbrook").demand(&"red"), 1.5)
	assert_eq(sim.market(&"millbrook").demand(&"yellow"), 1.0)
	assert_eq(sim.snapshot().next_demand_event_ms, 14_686)
	sim.tick(14_320)
	assert_false(sim.demand_events().any(func(v: DemandEventView) -> bool: return v.started_at_ms == 6320),
		"the spike ended")


func test_a_version_6_save_has_no_demand_events_after_migration_and_schedules_one() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v6.json"),
		SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.demand_events().size(), 0)
	assert_eq(sim.snapshot().next_demand_event_ms, -1, "the migration does not draw a start")
	sim.tick(ContentFixture.EVENT_INTERVAL_MAX_MS + 1)
	assert_gt(sim.demand_events().size(), 0, "the first tick after the load set the next start")


func test_a_version_9_save_has_carts_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v9.json"),
		SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.transport_tier().id, &"cart")
	assert_eq(sim.links().map(func(v: LinkView) -> StringName: return v.vehicle), [&"cart", &"cart"])
	assert_true(sim.buy_transport_tier().ok, "the next tier is trucks")
	assert_eq(sim.transport_tier().id, &"truck")


## A save of version 10 (#11: transport tiers and vehicles), as the game wrote
## it: trucks, with link 1 (to the warehouse) still on a cart and link 2 (from
## the warehouse to millbrook) on a truck.
func test_a_version_10_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v10.json")

	var result := _load(text, SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.transport_tier().id, &"truck")
	assert_eq([sim.link(1).vehicle, sim.link(2).vehicle], [&"cart", &"truck"])
	assert_eq(sim.link(2).source_kind, LinkView.Source.WAREHOUSE)
	assert_eq(sim.link(2).transit_time_ms, ContentFixture.TRUCK_TRANSIT_TIME_MS)
	assert_eq(sim.money().format(), "17")
	assert_eq(sim.upgrade_vehicle(2).reason, CommandResult.Reason.VEHICLE_IS_CURRENT)
	assert_true(sim.upgrade_vehicle(1).ok)
	assert_eq(sim.link(1).vehicle, &"truck")


## A save of version 11 (#16: labs and research), as the game wrote it: earth
## tones is complete, a brown factory, cool mixes selected, and one green
## widget on its way to the lab.
func test_a_version_11_save_still_loads() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v11.json")

	var result := _load(text, SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 10_700)
	assert_eq(sim.labs(), [1] as Array[int])
	assert_eq(sim.research_item(&"earth_tones").status, ResearchView.Status.COMPLETE)
	assert_eq(sim.factory(5).color, &"brown")
	assert_eq(sim.selected_research(), &"cool_mixes")
	assert_eq(sim.research_item(&"cool_mixes").in_transit, {&"green": 1} as Dictionary[StringName, int])
	assert_eq(sim.link(6).destination_lab_id, 1)
	sim.tick(5000)
	assert_eq(sim.research_item(&"cool_mixes").paid, {&"green": 1} as Dictionary[StringName, int],
		"the green widget arrived and paid")


func test_a_version_10_save_has_no_labs_or_research_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v10.json"),
		SaveCodec.migrations(), ContentFixture.make_for_saves())

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.labs(), [] as Array[int])
	assert_eq(sim.selected_research(), &"")
	for view in sim.research():
		assert_ne(view.status, ResearchView.Status.COMPLETE)
		assert_eq(view.total_paid(), 0)
	assert_eq(sim.lab_stock(), {} as Dictionary[StringName, int])
	assert_false(sim.is_color_unlocked(&"brown"))
