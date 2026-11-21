extends GutTest
## Mixed factories: their input bays, links from other factories, recipes, and
## the shipment size rule for an input bay.

const SEED := 6
const MARKET := &"millbrook"
const TRANSIT_MS := 5000


## One widget per second for each line, factories that cost 10, shipments that
## cost 2 and take 5 seconds, and much money, so that money never limits a test.
func _sim(output_bay_capacity: int = 10, input_bay_capacity: int = 10) -> Simulation:
	var colors := ContentFixture.mixed_colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, output_bay_capacity,
			{"starting_money": 10_000, "input_bay_capacity": input_bay_capacity}),
		null, ContentFixture.transport_data(TRANSIT_MS, 2)))
	return Simulation.new(content, SEED)


func _build(sim: Simulation, color: StringName) -> int:
	var result := sim.build_factory(color)
	assert_true(result.ok, "build %s: %s" % [color, result.message])
	return result.value


func _feed(sim: Simulation, source_id: int, destination_id: int) -> int:
	var result := sim.make_factory_link(source_id, destination_id)
	assert_true(result.ok, "link: %s" % result.message)
	return result.value


func _ship(sim: Simulation, link_id: int) -> int:
	var result := sim.start_shipment(link_id)
	assert_true(result.ok, "ship: %s" % result.message)
	return result.value


## The input bay counts of the factory [param id], in recipe order.
func _bay_counts(sim: Simulation, id: int) -> Array:
	return sim.factory(id).input_bays.map(func(bay: InputBayView) -> int: return bay.count)


## A green factory and a yellow and a blue factory with full output bays
## (10 widgets each), each linked to the green factory. Returns
## [code][green, yellow_link, blue_link][/code].
func _green_line(sim: Simulation) -> Array[int]:
	var yellow := _build(sim, &"yellow")
	var blue := _build(sim, &"blue")
	var green := _build(sim, &"green")
	sim.tick(10_000)
	return [green, _feed(sim, yellow, green), _feed(sim, blue, green)]


# --- Building --------------------------------------------------------------------

func test_secondary_colors_can_be_built_but_research_colors_cannot() -> void:
	var sim := _sim()
	assert_eq(sim.buildable_factory_colors(), [&"red", &"yellow", &"blue", &"green", &"purple"] as Array[StringName])
	assert_true(sim.is_color_unlocked(&"green"))
	assert_false(sim.is_color_unlocked(&"brown"))
	assert_false(sim.is_color_unlocked(&"magenta"))


func test_a_mixed_factory_has_one_empty_input_bay_for_each_input_color() -> void:
	var sim := _sim(10, 8)
	var purple := sim.factory(_build(sim, &"purple"))

	assert_eq(purple.input_bays.size(), 2)
	var red := purple.input_bays[0]
	assert_eq([red.color, red.count, red.capacity, red.per_widget, red.in_transit], [&"red", 0, 8, 2, 0])
	var blue := purple.input_bays[1]
	assert_eq([blue.color, blue.count, blue.capacity, blue.per_widget], [&"blue", 0, 8, 1])
	assert_eq(purple.output_bay_count, 0)


func test_a_base_factory_has_no_input_bays() -> void:
	var sim := _sim()
	var red := sim.factory(_build(sim, &"red"))
	assert_eq(red.input_bays.size(), 0)
	assert_eq(red.missing_inputs(), [] as Array[StringName])


func test_a_new_mixed_factory_waits_for_all_of_its_inputs() -> void:
	var sim := _sim()
	var green := _build(sim, &"green")
	sim.tick(60_000)

	var view := sim.factory(green)
	assert_eq(view.status, FactoryView.Status.WAITING_FOR_INPUT)
	assert_true(view.is_stopped())
	assert_eq(view.missing_inputs(), [&"yellow", &"blue"] as Array[StringName])
	assert_eq(view.output_bay_count, 0)


# --- Links between factories ---------------------------------------------------------

func test_a_factory_can_link_its_color_to_a_factory_whose_recipe_uses_it() -> void:
	var sim := _sim()
	var yellow := _build(sim, &"yellow")
	var green := _build(sim, &"green")
	assert_false(sim.has_factory_link(yellow, green))

	var link := sim.link(_feed(sim, yellow, green))

	assert_true(sim.has_factory_link(yellow, green))
	assert_false(sim.has_link(yellow, MARKET))
	assert_eq(link.color, &"yellow")
	assert_eq(link.source_factory_id, yellow)
	assert_eq(link.destination_kind, LinkView.Destination.FACTORY)
	assert_eq(link.destination_factory_id, green)
	assert_eq(link.vehicle, &"cart")
	assert_eq(link.transit_time_ms, TRANSIT_MS)
	assert_true(sim.money().equals(BigNumber.from_int(10_000 - 20)), "the link is free")


func test_a_link_to_a_market_says_so() -> void:
	var sim := _sim()
	var red := _build(sim, &"red")
	var link := sim.link(sim.make_link(red, MARKET).value)
	assert_eq(link.destination_kind, LinkView.Destination.MARKET)
	assert_eq(link.destination_market_id, MARKET)


func test_a_mixed_factory_can_link_to_a_market() -> void:
	var sim := _sim()
	var line := _green_line(sim)
	_ship(sim, line[1])
	_ship(sim, line[2])
	sim.tick(TRANSIT_MS + 10_000)
	var to_market: int = sim.make_link(line[0], MARKET).value
	var money_before := sim.money()

	assert_eq(_ship(sim, to_market), 10)
	sim.tick(TRANSIT_MS)

	var earned := BigNumber.from_int(ContentFixture.PRICE * 10 - 2)
	assert_true(sim.money().equals(money_before.add(earned)), "money %s" % sim.money())


## Checks that [param result] failed with [param reason] and changed nothing.
func _assert_fails(sim: Simulation, make: Callable, reason: CommandResult.Reason, message_part: String) -> void:
	var before := sim.snapshot()
	var result: CommandResult = make.call()
	assert_false(result.ok, "the command fails")
	assert_eq(result.reason, reason, result.message)
	assert_string_contains(result.message, message_part)
	assert_eq(sim.snapshot(), before, "nothing changes")


func test_a_link_to_a_factory_whose_recipe_does_not_use_the_color_fails() -> void:
	var sim := _sim()
	var red := _build(sim, &"red")
	var green := _build(sim, &"green")
	var purple := _build(sim, &"purple")

	_assert_fails(sim, sim.make_factory_link.bind(red, green),
		CommandResult.Reason.NOT_A_RECIPE_INPUT, "Green factory #2 does not use red")
	_assert_fails(sim, sim.make_factory_link.bind(green, green),
		CommandResult.Reason.NOT_A_RECIPE_INPUT, "does not use green")
	_assert_fails(sim, sim.make_factory_link.bind(green, purple),
		CommandResult.Reason.NOT_A_RECIPE_INPUT, "does not use green")
	_assert_fails(sim, sim.make_factory_link.bind(green, red),
		CommandResult.Reason.NOT_A_RECIPE_INPUT, "Red factory #1 does not use green")


func test_a_link_to_or_from_a_missing_factory_fails() -> void:
	var sim := _sim()
	var green := _build(sim, &"green")
	_assert_fails(sim, sim.make_factory_link.bind(9, green), CommandResult.Reason.UNKNOWN_FACTORY, "#9")
	_assert_fails(sim, sim.make_factory_link.bind(green, 9), CommandResult.Reason.UNKNOWN_FACTORY, "#9")


func test_a_second_link_between_the_same_factories_fails() -> void:
	var sim := _sim()
	var blue := _build(sim, &"blue")
	var green := _build(sim, &"green")
	_feed(sim, blue, green)
	_assert_fails(sim, sim.make_factory_link.bind(blue, green), CommandResult.Reason.LINK_EXISTS,
		"already has a link to factory #2")


func test_two_factories_of_one_color_can_feed_the_same_input_bay() -> void:
	var sim := _sim()
	var blue_a := _build(sim, &"blue")
	var blue_b := _build(sim, &"blue")
	var green := _build(sim, &"green")
	sim.tick(3000)
	_ship(sim, _feed(sim, blue_a, green))
	_ship(sim, _feed(sim, blue_b, green))
	sim.tick(TRANSIT_MS)
	assert_eq(_bay_counts(sim, green), [0, 6])


# --- Shipments to input bays ------------------------------------------------------------

func test_a_shipment_to_a_mixed_factory_goes_into_the_input_bay_of_its_color() -> void:
	var sim := _sim()
	var line := _green_line(sim)

	assert_eq(_ship(sim, line[2]), 10)
	assert_eq(sim.factory(line[0]).input_bays[1].in_transit, 10, "the blue widgets are on their way")
	sim.tick(TRANSIT_MS - 1)
	assert_eq(_bay_counts(sim, line[0]), [0, 0], "not there yet")
	sim.tick(1)

	var view := sim.factory(line[0])
	assert_eq(_bay_counts(sim, line[0]), [0, 10])
	assert_eq(view.input_bays[1].in_transit, 0)
	assert_eq(view.status, FactoryView.Status.WAITING_FOR_INPUT)
	assert_eq(view.missing_inputs(), [&"yellow"] as Array[StringName])


func test_a_shipment_carries_no_more_than_the_free_space_in_the_input_bay() -> void:
	var sim := _sim(10, 6)
	var line := _green_line(sim)

	assert_eq(_ship(sim, line[2]), 6, "the bay holds 6")
	assert_eq(sim.factory(sim.link(line[2]).source_factory_id).output_bay_count, 4,
		"the rest stays in the blue factory")


func test_widgets_on_their_way_use_up_the_free_space_in_the_input_bay() -> void:
	var sim := _sim(10, 6)
	var blue_a := _build(sim, &"blue")
	var blue_b := _build(sim, &"blue")
	var green := _build(sim, &"green")
	sim.tick(4000)
	_ship(sim, _feed(sim, blue_a, green))
	var second := _feed(sim, blue_b, green)

	assert_eq(_ship(sim, second), 2, "4 are on the way, so 2 fit")
	_assert_fails(sim, sim.start_shipment.bind(second), CommandResult.Reason.NOTHING_TO_SHIP,
		"the blue input bay of Green factory #3 is full")
	sim.tick(TRANSIT_MS)
	assert_eq(_bay_counts(sim, green), [0, 6], "the bay is full and did not overflow")


func test_a_full_input_bay_accepts_a_shipment_again_after_the_factory_consumes() -> void:
	var sim := _sim(10, 4)
	var line := _green_line(sim)
	_ship(sim, line[1])
	_ship(sim, line[2])
	sim.tick(TRANSIT_MS)
	assert_eq(_bay_counts(sim, line[0]), [4, 4])
	assert_false(sim.start_shipment(line[2]).ok, "the bay is full")

	sim.tick(3000)

	assert_eq(_bay_counts(sim, line[0]), [1, 1])
	assert_eq(_ship(sim, line[2]), 3)


# --- Recipes ----------------------------------------------------------------------------

func test_a_mixed_factory_consumes_one_full_recipe_to_make_one_widget() -> void:
	var sim := _sim()
	var red := _build(sim, &"red")
	var blue := _build(sim, &"blue")
	var purple := _build(sim, &"purple")
	sim.tick(5000)
	_ship(sim, _feed(sim, red, purple))
	var blue_link := _feed(sim, blue, purple)
	sim.tick(1000)
	_ship(sim, blue_link)
	# 5 red widgets arrive at 10 s, and 6 blue at 11 s. Each purple needs 2 red
	# and 1 blue, and takes 1 s.
	sim.tick(TRANSIT_MS)
	assert_eq(_bay_counts(sim, purple), [5, 6])
	assert_eq(sim.factory(purple).output_bay_count, 0)

	sim.tick(1000)
	assert_eq(sim.factory(purple).output_bay_count, 1)
	assert_eq(_bay_counts(sim, purple), [3, 5])

	sim.tick(60_000)
	var view := sim.factory(purple)
	assert_eq(view.output_bay_count, 2, "5 red widgets make only 2 purple widgets")
	assert_eq(_bay_counts(sim, purple), [1, 4])
	assert_eq(view.status, FactoryView.Status.WAITING_FOR_INPUT)
	assert_eq(view.missing_inputs(), [&"red"] as Array[StringName])


func test_more_production_lines_consume_faster() -> void:
	var sim := _sim()
	var line := _green_line(sim)
	sim.add_production_line(line[0])
	sim.add_production_line(line[0])
	_ship(sim, line[1])
	_ship(sim, line[2])
	sim.tick(TRANSIT_MS)

	sim.tick(2000)

	assert_eq(sim.factory(line[0]).output_bay_count, 6)
	assert_eq(_bay_counts(sim, line[0]), [4, 4])


func test_a_waiting_factory_keeps_no_partial_progress() -> void:
	var sim := _sim()
	var yellow := _build(sim, &"yellow")
	var blue := _build(sim, &"blue")
	var green := _build(sim, &"green")
	sim.tick(1000)
	_ship(sim, _feed(sim, yellow, green))
	var blue_link := _feed(sim, blue, green)
	_ship(sim, blue_link)
	# 1 yellow and 1 blue arrive at 6 s. The green widget takes until 7 s.
	sim.tick(TRANSIT_MS + 999)
	assert_eq(sim.factory(green).output_bay_count, 0)
	sim.tick(1)
	assert_eq(sim.factory(green).output_bay_count, 1)

	# The factory waits for 10 s, and then 1 blue arrives (the yellow factory
	# made more meanwhile, but none is shipped).
	sim.tick(10_000)
	_ship(sim, blue_link)
	sim.tick(TRANSIT_MS)
	assert_eq(sim.factory(green).status, FactoryView.Status.WAITING_FOR_INPUT,
		"blue is there, but yellow is not")
	assert_eq(sim.factory(green).missing_inputs(), [&"yellow"] as Array[StringName])


func test_a_mixed_factory_stops_when_its_output_bay_is_full() -> void:
	var sim := _sim(3, 10)
	var yellow := _build(sim, &"yellow")
	var blue := _build(sim, &"blue")
	var green := _build(sim, &"green")
	sim.tick(3000)
	var yellow_link := _feed(sim, yellow, green)
	var blue_link := _feed(sim, blue, green)
	_ship(sim, yellow_link)
	_ship(sim, blue_link)
	sim.tick(TRANSIT_MS + 60_000)

	var view := sim.factory(green)
	assert_eq(view.output_bay_count, 3)
	assert_eq(view.status, FactoryView.Status.OUTPUT_BAY_FULL)
	assert_eq(_bay_counts(sim, green), [0, 0], "3 of each made 3 green widgets")

	_ship(sim, yellow_link)
	_ship(sim, blue_link)
	sim.tick(TRANSIT_MS + 60_000)
	view = sim.factory(green)
	assert_eq(view.status, FactoryView.Status.OUTPUT_BAY_FULL,
		"a full output bay wins over a missing input")
	assert_eq(_bay_counts(sim, green), [3, 3], "a stopped factory consumes nothing")

	_ship(sim, sim.make_link(green, MARKET).value)
	sim.tick(3000)
	assert_eq(sim.factory(green).output_bay_count, 3, "it starts again")
	assert_eq(_bay_counts(sim, green), [0, 0])


# --- Time ---------------------------------------------------------------------------------

func test_one_long_tick_gives_the_same_state_as_many_short_ticks_with_arrivals() -> void:
	var one := _sim(4, 6)
	var many := _sim(4, 6)
	for sim: Simulation in [one, many]:
		var line := _green_line(sim)
		sim.add_production_line(line[0])
		_ship(sim, line[1])
		sim.tick(1300)
		_ship(sim, line[2])
		sim.tick(700)
		_ship(sim, line[1])

	one.tick(30_000)
	for i in 300:
		many.tick(100)

	assert_eq(one.snapshot(), many.snapshot())
	assert_eq(one.factory(3).output_bay_count, 4, "the green factory made widgets")
