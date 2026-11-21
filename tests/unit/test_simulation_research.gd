extends GutTest
## Labs and research: building labs, links to labs, the selected research, its
## payment by widgets, and the colors that it unlocks.

const SEED := 16
const TRANSIT_MS := 5000


## One widget per second for each line, labs that cost 30, shipments that
## cost 2 and take 5 seconds, and the research of
## [method ContentFixture.research_data]: earth_tones (2 red, 2 yellow, and 2
## blue; unlocks brown), then cool_mixes (3 green; unlocks blue-green).
func _sim(starting_money: int = 10_000) -> Simulation:
	var colors := ContentFixture.mixed_colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": starting_money}),
		null, ContentFixture.transport_data(TRANSIT_MS, 2)))
	return Simulation.new(content, SEED)


func _ok(result: CommandResult, what: String) -> Variant:
	assert_true(result.ok, "%s: %s" % [what, result.message])
	return result.value


func _build(sim: Simulation, color: StringName) -> int:
	return _ok(sim.build_factory(color), "build %s" % color)


func _lab_link(sim: Simulation, factory_id: int, lab_id: int) -> int:
	return _ok(sim.make_lab_link(factory_id, lab_id), "link to lab")


## A lab and red, yellow, and blue factories with full output bays, each linked
## to the lab. Returns [code][red_link, yellow_link, blue_link][/code].
func _primary_lab(sim: Simulation) -> Array[int]:
	var lab: int = _ok(sim.build_lab(), "build lab")
	var links: Array[int] = []
	for color in [&"red", &"yellow", &"blue"]:
		links.append(_lab_link(sim, _build(sim, color), lab))
	sim.tick(10_000)
	return links


func _ship_all(sim: Simulation, links: Array[int]) -> void:
	for link in links:
		_ok(sim.start_shipment(link), "ship on link %d" % link)


# --- Labs ------------------------------------------------------------------------

func test_a_lab_costs_money() -> void:
	var sim := _sim()

	var result := sim.build_lab()

	assert_true(result.ok, result.message)
	assert_eq(result.value, 1)
	assert_eq(sim.labs(), [1] as Array[int])
	assert_true(sim.money().equals(BigNumber.from_int(10_000 - ContentFixture.LAB_COST)))
	assert_true(sim.lab_build_cost().equals(BigNumber.from_int(ContentFixture.LAB_COST)))


func test_a_lab_with_too_little_money_fails_with_a_reason_and_changes_nothing() -> void:
	var sim := _sim(ContentFixture.LAB_COST - 1)
	var before := sim.snapshot()

	var result := sim.build_lab()

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_MONEY)
	assert_string_contains(result.message, "lab")
	assert_eq(sim.snapshot(), before)


func test_a_factory_can_be_linked_to_a_lab() -> void:
	var sim := _sim()
	var lab: int = sim.build_lab().value
	var red := _build(sim, &"red")

	var link := _lab_link(sim, red, lab)

	var view := sim.link(link)
	assert_eq(view.destination_kind, LinkView.Destination.LAB)
	assert_eq(view.destination_lab_id, lab)
	assert_eq(view.color, &"red")
	assert_true(sim.has_lab_link(red, lab))


func test_a_link_to_a_lab_that_is_not_allowed_fails_with_a_reason_and_changes_nothing() -> void:
	var sim := _sim()
	var lab: int = sim.build_lab().value
	var red := _build(sim, &"red")
	_lab_link(sim, red, lab)
	var before := sim.snapshot()

	var cases := [
		[sim.make_lab_link(99, lab), CommandResult.Reason.UNKNOWN_FACTORY],
		[sim.make_lab_link(red, 99), CommandResult.Reason.UNKNOWN_LAB],
		[sim.make_lab_link(red, lab), CommandResult.Reason.LINK_EXISTS],
	]

	for entry in cases:
		var result: CommandResult = entry[0]
		assert_false(result.ok)
		assert_eq(result.reason, entry[1], result.message)
	assert_eq(sim.snapshot(), before)


# --- Research --------------------------------------------------------------------

func test_research_comes_from_data_with_its_cost_and_unlocks() -> void:
	var sim := _sim()

	var views := sim.research()

	assert_eq(views.map(func(v: ResearchView) -> StringName: return v.id), [&"earth_tones", &"cool_mixes"])
	var earth := views[0]
	assert_eq(earth.name, "Earth tones")
	assert_eq(earth.cost, {&"red": 2, &"yellow": 2, &"blue": 2} as Dictionary[StringName, int])
	assert_eq(earth.paid, {&"red": 0, &"yellow": 0, &"blue": 0} as Dictionary[StringName, int])
	assert_eq(earth.unlock_colors, [&"brown"] as Array[StringName])
	assert_eq(earth.status, ResearchView.Status.AVAILABLE)
	assert_eq(views[1].requires, [&"earth_tones"] as Array[StringName])
	assert_eq(views[1].status, ResearchView.Status.LOCKED)
	assert_eq(sim.selected_research(), &"")


func test_selecting_research_that_is_not_allowed_fails_with_a_reason_and_changes_nothing() -> void:
	var sim := _sim()
	var before := sim.snapshot()

	var unknown := sim.select_research(&"alchemy")
	var locked := sim.select_research(&"cool_mixes")

	assert_eq(unknown.reason, CommandResult.Reason.UNKNOWN_RESEARCH)
	assert_eq(locked.reason, CommandResult.Reason.RESEARCH_LOCKED)
	assert_string_contains(locked.message, "Earth tones")
	assert_eq(sim.snapshot(), before)


func test_the_lab_consumes_arriving_widgets_to_pay_for_the_selected_research() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)
	_ok(sim.select_research(&"earth_tones"), "select")

	_ok(sim.start_shipment(links[0]), "ship red")

	assert_eq(sim.link(links[0]).shipments_in_transit[0].count, 2,
		"the shipment carries only what the research needs")
	assert_eq(sim.factory(1).output_bay_count, 8, "the other red widgets stay in the bay")
	assert_eq(sim.research_item(&"earth_tones").in_transit[&"red"], 2)
	sim.tick(TRANSIT_MS)
	var view := sim.research_item(&"earth_tones")
	assert_eq(view.paid[&"red"], 2)
	assert_eq(view.in_transit[&"red"], 0)
	assert_eq(view.status, ResearchView.Status.SELECTED)
	assert_eq(sim.lab_stock(), {} as Dictionary[StringName, int])


func test_a_lab_accepts_nothing_with_no_research_selected() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)

	var result := sim.start_shipment(links[0])

	assert_eq(result.reason, CommandResult.Reason.NOTHING_TO_SHIP)
	assert_string_contains(result.message, "no research selected")


func test_a_lab_accepts_nothing_of_a_color_that_the_research_does_not_need() -> void:
	var sim := _sim()
	var lab: int = sim.build_lab().value
	var link := _lab_link(sim, _build(sim, &"green"), lab)
	sim.select_research(&"earth_tones")

	var result := sim.start_shipment(link)

	assert_eq(result.reason, CommandResult.Reason.NOTHING_TO_SHIP)


func test_a_paid_color_accepts_nothing_more() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)
	sim.select_research(&"earth_tones")
	_ship_all(sim, [links[0]])

	var result := sim.start_shipment(links[0])

	assert_eq(result.reason, CommandResult.Reason.NOTHING_TO_SHIP, "2 red widgets are on the way")
	assert_string_contains(result.message, "Earth tones needs no more red")


func test_complete_research_unlocks_its_colors() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)
	sim.select_research(&"earth_tones")
	assert_eq(sim.build_factory(&"brown").reason, CommandResult.Reason.COLOR_LOCKED)

	_ship_all(sim, links)
	sim.tick(TRANSIT_MS)

	var view := sim.research_item(&"earth_tones")
	assert_eq(view.status, ResearchView.Status.COMPLETE)
	assert_eq(view.paid, view.cost)
	assert_eq(sim.selected_research(), &"", "nothing is selected after completion")
	assert_true(sim.is_color_unlocked(&"brown"))
	assert_true(sim.buildable_factory_colors().has(&"brown"))
	assert_true(sim.build_factory(&"brown").ok)
	assert_false(sim.is_color_unlocked(&"blue_green"), "other research unlocks blue-green")
	assert_eq(sim.research_item(&"cool_mixes").status, ResearchView.Status.AVAILABLE)


func test_research_completes_at_the_arrival_inside_a_long_tick() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)
	sim.select_research(&"earth_tones")
	_ship_all(sim, links)

	sim.tick(TRANSIT_MS - 1)
	assert_false(sim.is_color_unlocked(&"brown"))
	sim.tick(100_000)

	assert_true(sim.is_color_unlocked(&"brown"))


func test_a_locked_color_names_the_research_that_unlocks_it() -> void:
	var result := _sim().build_factory(&"brown")

	assert_eq(result.reason, CommandResult.Reason.COLOR_LOCKED)
	assert_string_contains(result.message, "Earth tones")


func test_complete_research_cannot_be_selected_again() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)
	sim.select_research(&"earth_tones")
	_ship_all(sim, links)
	sim.tick(TRANSIT_MS)
	var before := sim.snapshot()

	var result := sim.select_research(&"earth_tones")

	assert_eq(result.reason, CommandResult.Reason.RESEARCH_COMPLETE)
	assert_eq(sim.snapshot(), before)


func test_research_keeps_its_progress_when_other_research_is_selected() -> void:
	var made := _sim_with_two_open_research()
	var sim: Simulation = made[0]
	var links: Array[int] = made[1]
	sim.select_research(&"cool_mixes")
	_ship_all(sim, [links[0]])
	sim.tick(TRANSIT_MS)
	assert_eq(sim.research_item(&"cool_mixes").paid[&"green"], 3)

	sim.select_research(&"warm_mixes")

	assert_eq(sim.research_item(&"cool_mixes").paid[&"green"], 3, "progress is kept")
	assert_eq(sim.research_item(&"cool_mixes").status, ResearchView.Status.AVAILABLE)
	assert_eq(sim.selected_research(), &"warm_mixes")


func test_widgets_that_arrive_after_a_switch_go_to_the_stock_and_pay_later() -> void:
	var made := _sim_with_two_open_research()
	var sim: Simulation = made[0]
	var links: Array[int] = made[1]
	sim.select_research(&"cool_mixes")
	_ship_all(sim, [links[0]])

	sim.select_research(&"warm_mixes")
	sim.tick(TRANSIT_MS)

	assert_eq(sim.lab_stock(), {&"green": 3} as Dictionary[StringName, int], "warm_mixes needs no green")
	assert_eq(sim.research_item(&"cool_mixes").paid[&"green"], 0)
	_ok(sim.select_research(&"cool_mixes"), "select again")
	assert_eq(sim.lab_stock(), {} as Dictionary[StringName, int])
	var view := sim.research_item(&"cool_mixes")
	assert_eq(view.paid[&"green"], 3)


func test_the_stock_can_complete_research_when_it_is_selected() -> void:
	var made := _sim_with_two_open_research()
	var sim: Simulation = made[0]
	var red_link := _lab_link(sim, _build(sim, &"red"), sim.labs()[0])
	sim.tick(1000)
	sim.select_research(&"warm_mixes")
	_ship_all(sim, [red_link])
	sim.select_research(&"cool_mixes")
	sim.tick(TRANSIT_MS)
	assert_eq(sim.lab_stock(), {&"red": 1} as Dictionary[StringName, int])

	_ok(sim.select_research(&"warm_mixes"), "select warm_mixes again")

	assert_eq(sim.research_item(&"warm_mixes").status, ResearchView.Status.COMPLETE)
	assert_eq(sim.selected_research(), &"")
	assert_true(sim.is_color_unlocked(&"brown"))
	assert_eq(sim.lab_stock(), {} as Dictionary[StringName, int])


func test_the_stock_counts_against_what_a_lab_accepts() -> void:
	var made := _sim_with_two_open_research()
	var sim: Simulation = made[0]
	var links: Array[int] = made[1]
	sim.select_research(&"cool_mixes")
	_ship_all(sim, [links[0]])
	sim.select_research(&"warm_mixes")
	sim.tick(TRANSIT_MS)
	sim.select_research(&"cool_mixes")
	# More yellow and blue arrive and make more green widgets.
	sim.start_shipment(1)
	sim.start_shipment(2)
	sim.tick(TRANSIT_MS + 3000)

	var count: int = _ok(sim.start_shipment(links[0]), "ship green")

	assert_eq(count, 2, "3 of 5 green are paid")
	sim.tick(TRANSIT_MS)
	assert_true(sim.is_color_unlocked(&"blue_green"))


## Research with no requirements: cool_mixes (5 green; unlocks blue-green) and
## warm_mixes (1 red; unlocks brown), a lab, and a green factory with 3
## widgets in its output bay, linked to the lab. Returns
## [code][sim, [green_link]][/code].
func _sim_with_two_open_research() -> Array:
	var colors := ContentFixture.mixed_colors_data()
	var research := {"lab_build_cost": ContentFixture.LAB_COST, "research": [
		{"id": "cool_mixes", "name": "Cool mixes", "cost": {"green": 5}, "unlocks": {"colors": ["blue_green"]}},
		{"id": "warm_mixes", "name": "Warm mixes", "cost": {"red": 1}, "unlocks": {"colors": ["brown"]}},
	]}
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": 10_000}),
		null, ContentFixture.transport_data(TRANSIT_MS, 2), {"events": []}, research))
	var sim := Simulation.new(content, SEED)
	var lab: int = sim.build_lab().value
	var yellow := _build(sim, &"yellow")
	var blue := _build(sim, &"blue")
	var green := _build(sim, &"green")
	_ok(sim.make_factory_link(yellow, green), "yellow to green")
	_ok(sim.make_factory_link(blue, green), "blue to green")
	sim.tick(3000)
	sim.start_shipment(1)
	sim.start_shipment(2)
	# 3 yellow and 3 blue arrive and make 3 green widgets.
	sim.tick(TRANSIT_MS + 3000)
	assert_eq(sim.factory(green).output_bay_count, 3)
	var links: Array[int] = [_lab_link(sim, green, lab)]
	return [sim, links]


func test_automatic_transport_to_a_lab_pays_for_research_with_no_more_input() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)
	for link in links:
		_ok(sim.buy_automatic_transport(link), "automate")
	sim.select_research(&"earth_tones")

	sim.tick(60_000)

	assert_true(sim.is_color_unlocked(&"brown"))
	assert_eq(sim.link(links[0]).automatic, LinkView.Automatic.NOTHING_TO_SHIP,
		"the lab accepts nothing with no research selected")


func test_one_long_tick_gives_the_same_research_as_many_short_ticks() -> void:
	var one := _sim()
	var many := _sim()
	for sim in [one, many]:
		var links := _primary_lab(sim)
		sim.select_research(&"earth_tones")
		_ship_all(sim, links)

	one.tick(20_000)
	for i in 200:
		many.tick(100)

	assert_eq(one.snapshot(), many.snapshot())


# --- Prestige and vehicles ---------------------------------------------------------

func test_a_prestige_clears_labs_and_research_as_in_a_new_run() -> void:
	var sim := _sim()
	var links := _primary_lab(sim)
	sim.select_research(&"earth_tones")
	_ship_all(sim, links)
	sim.tick(TRANSIT_MS)
	assert_true(sim.is_color_unlocked(&"brown"))
	sim.select_research(&"cool_mixes")
	_ok(sim.buy_prism(), "buy prism")

	_ok(sim.prestige(), "prestige")

	assert_eq(sim.labs(), [] as Array[int])
	assert_eq(sim.selected_research(), &"")
	assert_false(sim.is_color_unlocked(&"brown"), "complete research clears")
	for view in sim.research():
		assert_eq(view.total_paid(), 0)
		assert_ne(view.status, ResearchView.Status.COMPLETE)
	assert_eq(sim.build_factory(&"brown").reason, CommandResult.Reason.COLOR_LOCKED)
	assert_eq(sim.build_lab().value, 1, "lab ids start again")


func test_a_link_to_a_lab_uses_the_transport_tier_and_its_vehicle() -> void:
	var sim := _sim()
	var lab: int = sim.build_lab().value
	var red := _build(sim, &"red")
	_ok(sim.buy_transport_tier(), "buy trucks")
	var link := _lab_link(sim, red, lab)
	sim.tick(10_000)
	sim.select_research(&"earth_tones")

	var count: int = _ok(sim.start_shipment(link), "ship red")

	assert_eq(sim.link(link).vehicle, &"truck")
	assert_eq(count, 2, "the shipment carries only what the research needs")
	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)
	assert_eq(sim.research_item(&"earth_tones").paid[&"red"], 2, "trucks arrive in their own transit time")


func test_a_warehouse_can_feed_a_lab() -> void:
	var sim := _sim()
	var lab: int = sim.build_lab().value
	var red := _build(sim, &"red")
	var warehouse: int = _ok(sim.build_warehouse(&"red"), "build warehouse")
	var into: int = _ok(sim.link_factory_to_warehouse(red, warehouse), "link to warehouse")
	var out: int = _ok(sim.link_warehouse_to_lab(warehouse, lab), "link warehouse to lab")
	sim.tick(5000)
	_ok(sim.start_shipment(into), "ship to warehouse")
	sim.tick(TRANSIT_MS)
	sim.select_research(&"earth_tones")

	assert_eq(sim.link(out).source_kind, LinkView.Source.WAREHOUSE)
	assert_eq(_ok(sim.start_shipment(out), "ship to lab"), 2)
	assert_eq(sim.warehouse(warehouse).count, 3)
	sim.tick(TRANSIT_MS)
	assert_eq(sim.research_item(&"earth_tones").paid[&"red"], 2)
	assert_eq(sim.link_warehouse_to_lab(warehouse, lab).reason, CommandResult.Reason.LINK_EXISTS)
	assert_eq(sim.link_warehouse_to_lab(warehouse, 9).reason, CommandResult.Reason.UNKNOWN_LAB)
