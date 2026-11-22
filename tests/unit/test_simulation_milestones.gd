extends GutTest
## Milestones (#25): the core records what the player did across all runs and
## sends an event when a milestone goes up (see ADR-0019). Platform
## achievements react to the events outside the core.

const SEED := 25

## Each [code][id, value][/code] that the simulation sent, in order.
var _sent: Array = []


## Content with mixed colors, research, and 10000 money at the start.
func _content() -> Content:
	return ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(1000, 10, {"starting_money": 10_000})))


## A new game whose milestone events go to [member _sent].
func _sim() -> Simulation:
	return _listen(Simulation.new(_content(), SEED))


func _listen(sim: Simulation) -> Simulation:
	_sent = []
	sim.milestone_reached.connect(func(id: StringName, value: int) -> void: _sent.append([id, value]))
	return sim


func _ok(result: CommandResult) -> Variant:
	assert_true(result.ok, result.message)
	return result.value


## A red factory with a link to the market, and one shipment that sells.
func _sell_once(sim: Simulation) -> void:
	var factory: int = _ok(sim.build_factory(&"red"))
	var link: int = _ok(sim.make_link(factory, &"millbrook"))
	sim.tick(2000)
	_ok(sim.start_shipment(link))
	sim.tick(ContentFixture.TRANSIT_TIME_MS)


func test_a_new_game_has_no_milestones() -> void:
	var sim := _sim()

	assert_eq(sim.milestones(), {} as Dictionary[StringName, int])
	assert_eq(sim.snapshot().milestones, [])


func test_the_first_sale_sends_an_event_once() -> void:
	var sim := _sim()
	_sell_once(sim)
	assert_true(_sent.has([Milestones.FIRST_SALE, 1]))
	assert_eq(sim.milestones()[Milestones.FIRST_SALE], 1)

	_sent = []
	_ok(sim.start_shipment(1))
	sim.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_eq(_sent, [], "a second sale sends nothing")


func test_a_shipment_on_its_way_is_not_a_sale() -> void:
	var sim := _sim()
	var factory: int = _ok(sim.build_factory(&"red"))
	var link: int = _ok(sim.make_link(factory, &"millbrook"))
	sim.tick(2000)
	_ok(sim.start_shipment(link))
	sim.tick(ContentFixture.TRANSIT_TIME_MS - 1)

	assert_false(sim.milestones().has(Milestones.FIRST_SALE))


func test_factories_send_their_color_the_first_mixed_factory_and_the_count() -> void:
	var sim := _sim()
	_ok(sim.build_factory(&"yellow"))
	_ok(sim.build_factory(&"blue"))
	_ok(sim.build_factory(&"green"))
	_ok(sim.build_factory(&"green"))

	assert_eq(_sent, [
		[&"factory.yellow", 1], [Milestones.FACTORIES, 1],
		[&"factory.blue", 1], [Milestones.FACTORIES, 2],
		[&"factory.green", 1], [Milestones.FIRST_MIXED_FACTORY, 1], [Milestones.FACTORIES, 3],
		[Milestones.FACTORIES, 4],
	])


func test_a_failed_command_sends_nothing() -> void:
	var sim := _listen(Simulation.new(ContentFixture.from_data(ContentFixture.data(
		ContentFixture.mixed_colors_data(), ContentFixture.balance_data(1000, 10, {"starting_money": 0}))), SEED))

	assert_false(sim.build_factory(&"red").ok)
	assert_false(sim.buy_prism().ok)
	assert_false(sim.buy_transport_tier().ok)

	assert_eq(_sent, [])
	assert_eq(sim.milestones(), {} as Dictionary[StringName, int])


func test_each_first_of_logistics_and_markets_sends_an_event() -> void:
	var sim := _sim()
	var red: int = _ok(sim.build_factory(&"red"))
	var link: int = _ok(sim.make_link(red, &"millbrook"))
	_ok(sim.buy_automatic_transport(link))
	_ok(sim.make_community_investment(&"millbrook", MarketView.Investment.INCOME))
	_ok(sim.buy_transport_tier())
	_ok(sim.build_factory(&"red"))
	var warehouse: int = _ok(sim.build_warehouse(&"red"))
	var second: int = _ok(sim.link_factory_to_warehouse(red, warehouse))
	_ok(sim.buy_automatic_transport(second))
	_ok(sim.set_split({link: 50, second: 50}))

	var milestones := sim.milestones()
	for id: StringName in [Milestones.FIRST_AUTOMATIC_TRANSPORT, Milestones.FIRST_COMMUNITY_INVESTMENT,
			&"transport_tier.truck", Milestones.FIRST_WAREHOUSE, Milestones.FIRST_SPLIT]:
		assert_eq(milestones.get(id), 1, String(id))
		assert_eq(_sent.count([id, 1]), 1, "%s is sent once" % id)


func test_complete_research_sends_its_milestone_during_a_tick() -> void:
	var sim := _sim()
	var lab: int = _ok(sim.build_lab())
	var links: Array[int] = []
	for color: StringName in [&"red", &"yellow", &"blue"]:
		var factory: int = _ok(sim.build_factory(color))
		links.append(_ok(sim.make_lab_link(factory, lab)))
	_ok(sim.select_research(&"earth_tones"))
	sim.tick(3000)
	for link in links:
		_ok(sim.start_shipment(link))
	_sent = []

	sim.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_eq(sim.research_item(&"earth_tones").status, ResearchView.Status.COMPLETE)
	assert_eq(_sent, [[&"research.earth_tones", 1], [Milestones.FIRST_RESEARCH, 1]])


func test_prisms_and_prestiges_count_and_a_prestige_keeps_the_milestones() -> void:
	var sim := _sim()
	_sell_once(sim)
	_ok(sim.buy_prism())
	_ok(sim.buy_prism())
	_ok(sim.buy_prestige_upgrade(&"quick_lines"))
	_ok(sim.prestige())
	_ok(sim.buy_prism())
	_ok(sim.prestige())

	var milestones := sim.milestones()
	assert_eq(milestones[Milestones.PRISMS_BOUGHT], 3)
	assert_eq(milestones[Milestones.PRESTIGES], 2)
	assert_eq(milestones[Milestones.FIRST_SALE], 1, "a prestige keeps the first sale")
	assert_eq(milestones[&"factory.red"], 1, "a prestige keeps the first factory")
	assert_eq(milestones[&"prestige_upgrade.quick_lines"], 1)
	assert_true(_sent.has([Milestones.PRESTIGES, 1]))
	assert_true(_sent.has([Milestones.PRESTIGES, 2]))


func test_offline_progress_sends_the_events_of_its_tick() -> void:
	var sim := _sim()
	var factory: int = _ok(sim.build_factory(&"red"))
	var link: int = _ok(sim.make_link(factory, &"millbrook"))
	sim.tick(2000)
	_ok(sim.buy_automatic_transport(link))

	sim.progress_offline(ContentFixture.TRANSIT_TIME_MS * 3)

	assert_true(_sent.has([Milestones.FIRST_SALE, 1]))


func test_one_long_tick_gives_the_milestones_of_many_short_ticks() -> void:
	var long := _sim()
	var short := Simulation.new(_content(), SEED)
	for sim: Simulation in [long, short]:
		var factory: int = _ok(sim.build_factory(&"red"))
		_ok(sim.buy_automatic_transport(_ok(sim.make_link(factory, &"millbrook"))))
	long.tick(20_000)
	for i in 200:
		short.tick(100)

	assert_eq(long.snapshot().milestones, short.snapshot().milestones)
	assert_true(long.milestones().has(Milestones.FIRST_SALE))


func test_changing_the_query_result_does_not_change_the_game() -> void:
	var sim := _sim()
	_ok(sim.build_factory(&"red"))

	sim.milestones()[&"factory.red"] = 99

	assert_eq(sim.milestones()[&"factory.red"], 1)


func test_a_load_keeps_the_milestones_and_sends_nothing() -> void:
	var sim := _sim()
	_sell_once(sim)
	_ok(sim.buy_prism())
	_ok(sim.prestige())

	var reader := SnapshotReader.new(JSON.parse_string(JSON.stringify(sim.snapshot())))
	var loaded := Simulation.from_snapshot(_content(), reader)
	assert_eq(reader.errors(), PackedStringArray())
	_listen(loaded)

	assert_eq(loaded.milestones(), sim.milestones())
	assert_eq(_sent, [])


func test_a_load_raises_the_milestones_that_the_state_shows() -> void:
	var sim := _sim()
	_ok(sim.build_factory(&"yellow"))
	_ok(sim.build_factory(&"blue"))
	_ok(sim.build_factory(&"green"))
	_ok(sim.buy_transport_tier())
	_ok(sim.buy_prism())
	var state := JSON.parse_string(JSON.stringify(sim.snapshot())) as Dictionary
	state.milestones = []

	var reader := SnapshotReader.new(state)
	var loaded := Simulation.from_snapshot(_content(), reader)

	assert_eq(reader.errors(), PackedStringArray())
	assert_eq(loaded.milestones(), sim.milestones())


func test_a_milestone_that_does_not_exist_fails_the_load() -> void:
	var state := _sim().snapshot()
	state.milestones = [{"id": "dance", "value": 1, "imported": 0}]
	state = JSON.parse_string(JSON.stringify(state))

	var reader := SnapshotReader.new(state)
	Simulation.from_snapshot(_content(), reader)

	assert_eq(reader.errors().size(), 1)
	assert_string_contains(reader.errors()[0], "state.milestones[0].id")


func test_a_milestone_twice_fails_the_load() -> void:
	var state := _sim().snapshot()
	state.milestones = [{"id": "first_sale", "value": 1, "imported": 0},
		{"id": "first_sale", "value": 2, "imported": 0}]
	state = JSON.parse_string(JSON.stringify(state))

	var reader := SnapshotReader.new(state)
	Simulation.from_snapshot(_content(), reader)

	assert_eq(reader.errors().size(), 1)
	assert_string_contains(reader.errors()[0], "state.milestones[1].id")


func test_a_milestone_below_1_fails_the_load() -> void:
	var state := _sim().snapshot()
	state.milestones = [{"id": "first_sale", "value": 0, "imported": 0}]
	state = JSON.parse_string(JSON.stringify(state))

	var reader := SnapshotReader.new(state)
	Simulation.from_snapshot(_content(), reader)

	assert_eq(reader.errors().size(), 1)
	assert_string_contains(reader.errors()[0], "state.milestones[0].value")


func test_an_imported_value_above_the_value_fails_the_load() -> void:
	var state := _sim().snapshot()
	state.milestones = [{"id": "prisms_bought", "value": 2, "imported": 3}]
	state = JSON.parse_string(JSON.stringify(state))

	var reader := SnapshotReader.new(state)
	Simulation.from_snapshot(_content(), reader)

	assert_eq(reader.errors().size(), 1)
	assert_string_contains(reader.errors()[0], "state.milestones[0].imported")


# --- Imported milestones (ADR-0019) ---------------------------------------------

func test_a_new_game_has_no_imported_milestones() -> void:
	var sim := _sim()
	_sell_once(sim)

	assert_eq(sim.imported_milestones(), {} as Dictionary[StringName, int])


func test_marking_an_import_records_each_milestone_and_sends_nothing() -> void:
	var sim := _sim()
	_sell_once(sim)
	_ok(sim.buy_prism())
	_sent = []

	_ok(sim.mark_milestones_imported())

	assert_eq(sim.imported_milestones(), sim.milestones())
	assert_eq(_sent, [])


func test_a_milestone_goes_up_after_an_import_and_the_imported_value_stays() -> void:
	var sim := _sim()
	_ok(sim.buy_prism())
	_ok(sim.mark_milestones_imported())
	_sent = []

	_ok(sim.buy_prism())

	assert_eq(sim.milestones()[Milestones.PRISMS_BOUGHT], 2)
	assert_eq(sim.imported_milestones()[Milestones.PRISMS_BOUGHT], 1)
	assert_eq(_sent, [[Milestones.PRISMS_BOUGHT, 2]])


func test_a_save_and_a_prestige_keep_the_imported_milestones() -> void:
	var sim := _sim()
	_ok(sim.buy_prism())
	_ok(sim.mark_milestones_imported())
	var imported := sim.imported_milestones()

	var loaded := SaveCodec.decode(_content(), SaveCodec.encode(sim, 0))
	assert_true(loaded.ok, loaded.message)
	assert_eq(loaded.simulation.imported_milestones(), imported)
	assert_eq(loaded.simulation.snapshot(), sim.snapshot())
	_ok(loaded.simulation.prestige())
	assert_eq(loaded.simulation.imported_milestones(), imported)


func test_the_ids_have_one_for_each_item_of_the_content() -> void:
	var ids := Milestones.ids(_content())

	for id: StringName in Milestones.SINGLE:
		assert_true(ids.has(id), String(id))
	for id: StringName in [&"factory.red", &"factory.brown", &"transport_tier.truck",
			&"research.earth_tones", &"prestige_upgrade.quick_lines"]:
		assert_true(ids.has(id), String(id))
	assert_false(ids.has(&"transport_tier.cart"), "each game starts with the first tier")
