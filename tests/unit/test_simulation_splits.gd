extends GutTest
## Splits: the percentage of a color's widgets at one source that goes to each
## of its automatic links.

const SEED := 14
const MARKETS: PackedStringArray = ["millbrook", "ashford", "cobble"]
const TRANSIT_MS := 5000


## One widget per second for each line, an output bay of
## [param output_bay_capacity], three markets, shipments that cost 2 and take
## 5 seconds, and much money, so that money never limits a test.
func _sim(output_bay_capacity: int = 10) -> Simulation:
	var colors := ContentFixture.mixed_colors_data()
	var content := ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, output_bay_capacity, {"starting_money": 100_000}),
		ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS),
		ContentFixture.transport_data(TRANSIT_MS, 2)))
	return Simulation.new(content, SEED)


func _build(sim: Simulation, color: StringName = &"red") -> int:
	var result := sim.build_factory(color)
	assert_true(result.ok, "build %s: %s" % [color, result.message])
	return result.value


func _link(sim: Simulation, factory_id: int, market: StringName) -> int:
	var result := sim.make_link(factory_id, market)
	assert_true(result.ok, "link: %s" % result.message)
	return result.value


func _automate(sim: Simulation, link_id: int) -> int:
	var result := sim.buy_automatic_transport(link_id)
	assert_true(result.ok, "automate: %s" % result.message)
	return link_id


## A red factory with an automatic link to each of the three markets.
## Returns the link ids, in market order.
func _three_way(sim: Simulation) -> Array[int]:
	var red := _build(sim)
	var ids: Array[int] = []
	for market in MARKETS:
		ids.append(_automate(sim, _link(sim, red, StringName(market))))
	return ids


func _set_split(sim: Simulation, shares: Dictionary) -> void:
	var result := sim.set_split(shares)
	assert_true(result.ok, "set split: %s" % result.message)


func _assert_fails(sim: Simulation, result: CommandResult, reason: CommandResult.Reason,
		message: String, before: Dictionary) -> void:
	assert_false(result.ok, "the command fails")
	assert_eq(result.reason, reason, result.message)
	assert_eq(result.message, message)
	assert_eq(sim.snapshot(), before, "a failed command changes nothing")


## The widgets that each link in [param ids] shipped since its split was set.
func _shipped(sim: Simulation, ids: Array[int]) -> Array:
	var split := sim.splits()[0]
	return ids.map(func(id: int) -> int: return split.shipped[id])


# --- Setting a split -------------------------------------------------------------

func test_a_new_source_has_no_split() -> void:
	var sim := _sim()
	var ids := _three_way(sim)

	assert_eq(sim.splits().size(), 0)
	assert_eq(sim.link(ids[0]).split_percent, LinkView.NO_SPLIT)


func test_a_split_sets_the_percentage_of_each_link() -> void:
	var sim := _sim()
	var ids := _three_way(sim)

	var result := sim.set_split({ids[0]: 50, ids[1]: 30, ids[2]: 20})

	assert_true(result.ok, result.message)
	var splits := sim.splits()
	assert_eq(splits.size(), 1)
	var split := splits[0]
	assert_eq(split.source_factory_id, 1)
	assert_eq(split.color, &"red")
	assert_eq(split.shares, {ids[0]: 50, ids[1]: 30, ids[2]: 20})
	assert_eq(split.shipped, {ids[0]: 0, ids[1]: 0, ids[2]: 0})
	assert_eq([sim.link(ids[0]).split_percent, sim.link(ids[1]).split_percent,
		sim.link(ids[2]).split_percent], [50, 30, 20])


func test_a_link_left_out_of_a_split_gets_0_percent() -> void:
	var sim := _sim()
	var ids := _three_way(sim)

	_set_split(sim, {ids[0]: 60, ids[2]: 40})

	assert_eq(sim.splits()[0].shares, {ids[0]: 60, ids[1]: 0, ids[2]: 40})
	assert_eq(sim.link(ids[1]).split_percent, 0)


func test_one_link_can_have_the_whole_split() -> void:
	var sim := _sim()
	var ids := _three_way(sim)

	_set_split(sim, {ids[1]: 100})

	assert_eq(sim.splits()[0].shares, {ids[0]: 0, ids[1]: 100, ids[2]: 0})


func test_each_source_has_its_own_split() -> void:
	var sim := _sim()
	var red_ids := _three_way(sim)
	var blue := _build(sim, &"blue")
	var blue_ids: Array[int] = [_automate(sim, _link(sim, blue, &"millbrook")),
		_automate(sim, _link(sim, blue, &"ashford"))]

	_set_split(sim, {blue_ids[0]: 25, blue_ids[1]: 75})
	_set_split(sim, {red_ids[0]: 100})

	var splits := sim.splits()
	assert_eq(splits.map(func(s: SplitView) -> Array: return [s.source_factory_id, s.color]),
		[[1, &"red"], [blue, &"blue"]], "splits in the order of their first link")
	assert_eq(splits[1].shares, {blue_ids[0]: 25, blue_ids[1]: 75})


func test_a_split_that_does_not_add_up_to_100_fails() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	var before := sim.snapshot()

	_assert_fails(sim, sim.set_split({ids[0]: 50, ids[1]: 40}), CommandResult.Reason.SPLIT_NOT_100,
		"The percentages of a split must add up to 100, but these add up to 90.", before)
	_assert_fails(sim, sim.set_split({ids[0]: 60, ids[1]: 50}), CommandResult.Reason.SPLIT_NOT_100,
		"The percentages of a split must add up to 100, but these add up to 110.", before)
	_assert_fails(sim, sim.set_split({}), CommandResult.Reason.SPLIT_NOT_100,
		"The percentages of a split must add up to 100, but these add up to 0.", before)


func test_a_percentage_out_of_range_fails() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	var before := sim.snapshot()

	_assert_fails(sim, sim.set_split({ids[0]: 110, ids[1]: -10}), CommandResult.Reason.BAD_PERCENT,
		"A percentage must be a whole number from 0 to 100, but link #%d has 110." % ids[0], before)
	_assert_fails(sim, sim.set_split({ids[0]: 50.5, ids[1]: 49.5}), CommandResult.Reason.BAD_PERCENT,
		"A percentage must be a whole number from 0 to 100, but link #%d has 50.5." % ids[0], before)


func test_a_split_on_an_unknown_link_fails() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	var before := sim.snapshot()

	_assert_fails(sim, sim.set_split({ids[0]: 50, 99: 50}), CommandResult.Reason.UNKNOWN_LINK,
		"There is no link #99.", before)
	_assert_fails(sim, sim.set_split({"one": 100}), CommandResult.Reason.UNKNOWN_LINK,
		"There is no link \"one\".", before)


func test_a_split_on_a_manual_link_fails() -> void:
	var sim := _sim()
	_three_way(sim)
	var manual := _link(sim, _build(sim, &"blue"), &"millbrook")
	var before := sim.snapshot()

	_assert_fails(sim, sim.set_split({manual: 100}), CommandResult.Reason.NOT_AUTOMATIC,
		"Link #%d has manual transport. A split is only across automatic links." % manual, before)


func test_a_split_across_two_sources_fails() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	var other := _automate(sim, _link(sim, _build(sim), &"millbrook"))
	var before := sim.snapshot()

	_assert_fails(sim, sim.set_split({ids[0]: 50, other: 50}), CommandResult.Reason.MIXED_SOURCES,
		"Link #%d does not start at Red factory #1. A split is across the links of one color from one source." % other,
		before)


# --- Shipping by the split -------------------------------------------------------

func test_over_ticks_each_link_gets_its_percentage() -> void:
	var sim := _sim(100)
	var red := _build(sim)
	sim.add_production_line(red)
	sim.add_production_line(red)
	var ids: Array[int] = []
	# The links start at different times, so they do not ship at the same time.
	for i in MARKETS.size():
		ids.append(_automate(sim, _link(sim, red, StringName(MARKETS[i]))))
		sim.tick(1700)
	_set_split(sim, {ids[0]: 50, ids[1]: 30, ids[2]: 20})

	sim.tick(600_000)

	var shipped := _shipped(sim, ids)
	var total: int = shipped[0] + shipped[1] + shipped[2]
	assert_gt(total, 1700, "about 3 widgets each second for 600 s")
	for i in ids.size():
		var want: int = [50, 30, 20][i] * total / 100
		assert_almost_eq(shipped[i], want, 3, "link %d gets its percentage" % ids[i])
	# Throughput counts whole shipments, so it can be one shipment off.
	assert_almost_eq(sim.link(ids[0]).widgets_per_minute, 90, 8, "50% of 180 widgets a minute")
	assert_almost_eq(sim.link(ids[2]).widgets_per_minute, 36, 8, "20% of 180 widgets a minute")


func test_the_split_is_the_same_in_one_long_tick_and_many_short_ticks() -> void:
	var long := _sim()
	var short := _sim()
	for sim: Simulation in [long, short]:
		var ids := _three_way(sim)
		sim.tick(1300)
		_set_split(sim, {ids[0]: 15, ids[1]: 45, ids[2]: 40})

	long.tick(97_000)
	for i in 970:
		short.tick(100)

	assert_eq(long.snapshot(), short.snapshot())


func test_a_link_at_0_percent_ships_nothing() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	_set_split(sim, {ids[0]: 100})

	sim.tick(60_000)

	assert_eq(sim.link(ids[1]).widgets_per_minute, 0)
	assert_eq(sim.link(ids[1]).automatic, LinkView.Automatic.NOTHING_TO_SHIP)
	assert_gt(sim.link(ids[0]).widgets_per_minute, 50)


func test_a_manual_shipment_from_a_source_with_a_split_takes_widgets_outside_the_split() -> void:
	var sim := _sim()
	var red := _build(sim)
	var automatic := _automate(sim, _link(sim, red, &"millbrook"))
	var manual := _link(sim, red, &"ashford")
	_set_split(sim, {automatic: 100})
	sim.tick(3000)
	assert_eq(sim.link(manual).split_percent, 0)

	var shipped := sim.start_shipment(manual)

	assert_true(shipped.ok, shipped.message)
	assert_eq(shipped.value, 3, "the manual link takes all the widgets")
	assert_eq(sim.splits()[0].shipped, {automatic: 0, manual: 0}, "they do not count in the split")


func test_a_shipment_by_hand_on_a_link_of_a_split_is_outside_the_split() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	_set_split(sim, {ids[0]: 50, ids[1]: 50})
	# At 5 s, the bay has 5 widgets. Each link takes 2 of them, and 1 waits.
	sim.tick(5001)
	assert_eq(_shipped(sim, ids), [2, 2, 0])
	assert_eq(sim.factory(1).output_bay_count, 1)

	var shipped := sim.start_shipment(ids[2])

	assert_true(shipped.ok, shipped.message)
	assert_eq(shipped.value, 1, "the link at 0% ships by hand")
	assert_eq(_shipped(sim, ids), [2, 2, 0])


func test_the_split_keeps_its_percentages_when_manual_shipments_take_widgets() -> void:
	var sim := _sim(100)
	var red := _build(sim)
	sim.add_production_line(red)
	var ids: Array[int] = [_automate(sim, _link(sim, red, &"millbrook")),
		_automate(sim, _link(sim, red, &"ashford"))]
	var manual := _link(sim, red, &"cobble")
	_set_split(sim, {ids[0]: 75, ids[1]: 25})

	for i in 60:
		sim.tick(4100)
		sim.start_shipment(manual)

	var shipped := _shipped(sim, ids)
	assert_gt(shipped[0] + shipped[1], 100, "automatic links ship too")
	assert_almost_eq(shipped[0], 3 * shipped[1], 4, "75% and 25% of what the automatic links ship")


func test_a_blocked_link_keeps_its_share_and_the_source_fills_up() -> void:
	var sim := _sim()
	var red := _build(sim)
	var purple := _build(sim, &"purple")
	var to_market := _automate(sim, _link(sim, red, &"millbrook"))
	var feed: int = sim.make_factory_link(red, purple).value
	_automate(sim, feed)
	_set_split(sim, {to_market: 50, feed: 50})

	# With no blue widgets, purple consumes no red, so its red bay of 10 fills.
	sim.tick(120_000)

	# Of 39 widgets, the market gets 50% rounded down (19). 10 widgets wait in
	# the full output bay, and 9 of them are for purple.
	assert_eq(_shipped(sim, [to_market, feed]), [19, 10])
	assert_eq(sim.factory(red).output_bay_count, 10)
	assert_eq(sim.factory(red).status, FactoryView.Status.OUTPUT_BAY_FULL)


func test_a_blocked_link_gets_its_share_when_it_can_take_widgets_again() -> void:
	var sim := _sim(40)
	var red := _build(sim)
	var purple := _build(sim, &"purple")
	var to_market := _automate(sim, _link(sim, red, &"millbrook"))
	var feed: int = sim.make_factory_link(red, purple).value
	_automate(sim, feed)
	_set_split(sim, {to_market: 50, feed: 50})
	sim.tick(60_000)
	# Now purple gets blue widgets and sells what it makes.
	var blue := _build(sim, &"blue")
	_automate(sim, sim.make_factory_link(blue, purple).value)
	_automate(sim, _link(sim, purple, &"ashford"))

	sim.tick(600_000)

	var shipped := _shipped(sim, [to_market, feed])
	assert_almost_eq(shipped[1], shipped[0], 12, "purple caught up to its 50%")


# --- Links and splits that change -------------------------------------------------

func test_a_new_link_from_a_source_with_a_split_gets_0_percent() -> void:
	var sim := _sim()
	var red := _build(sim)
	var first := _automate(sim, _link(sim, red, &"millbrook"))
	_set_split(sim, {first: 100})

	var second := _automate(sim, _link(sim, red, &"ashford"))
	sim.tick(30_000)

	assert_eq(sim.splits()[0].shares, {first: 100, second: 0})
	assert_eq(sim.link(second).widgets_per_minute, 0)


func test_a_new_split_counts_from_0() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	_set_split(sim, {ids[0]: 100})
	sim.tick(30_000)
	assert_gt(_shipped(sim, ids)[0], 0)

	_set_split(sim, {ids[1]: 100})

	assert_eq(_shipped(sim, ids), [0, 0, 0])
	sim.tick(30_000)
	assert_eq(_shipped(sim, ids)[0], 0, "the first link gets 0% now")
	assert_gt(_shipped(sim, ids)[1], 0)


func test_clearing_a_split_lets_each_link_take_what_it_can() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	_set_split(sim, {ids[0]: 100})

	var result := sim.clear_split(ids[1])

	assert_true(result.ok, result.message)
	assert_eq(sim.splits().size(), 0)
	assert_eq(sim.link(ids[0]).split_percent, LinkView.NO_SPLIT)
	sim.tick(9_000)
	var waiting := sim.factory(1).output_bay_count
	assert_gt(waiting, 0)
	var shipped := sim.start_shipment(ids[1])
	assert_true(shipped.ok, shipped.message)
	assert_eq(shipped.value, waiting, "the link takes all the widgets")


func test_clearing_a_split_that_is_not_there_fails() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	var before := sim.snapshot()

	_assert_fails(sim, sim.clear_split(ids[0]), CommandResult.Reason.NO_SPLIT,
		"Red factory #1 has no split.", before)
	_assert_fails(sim, sim.clear_split(99), CommandResult.Reason.UNKNOWN_LINK,
		"There is no link #99.", before)


# --- Warehouses and prestige ----------------------------------------------------

## A red factory that sends all its widgets to a red warehouse, and two
## automatic links from the warehouse, to millbrook and to ashford. Returns
## [code][warehouse, to_millbrook, to_ashford][/code].
func _warehouse_two_way(sim: Simulation) -> Array[int]:
	var red := _build(sim)
	var warehouse: int = sim.build_warehouse(&"red").value
	_automate(sim, sim.link_factory_to_warehouse(red, warehouse).value)
	return [warehouse, _automate(sim, sim.link_warehouse_to_market(warehouse, &"millbrook").value),
		_automate(sim, sim.link_warehouse_to_market(warehouse, &"ashford").value)]


func test_a_warehouse_has_a_split_of_its_own() -> void:
	var sim := _sim()
	var ends := _warehouse_two_way(sim)

	_set_split(sim, {ends[1]: 75, ends[2]: 25})

	var split := sim.splits()[0]
	assert_eq([split.source_kind, split.source_warehouse_id, split.source_factory_id, split.color],
		[LinkView.Source.WAREHOUSE, ends[0], 0, &"red"])
	assert_eq(split.shares, {ends[1]: 75, ends[2]: 25}, "the link into the warehouse is not in its split")


func test_over_ticks_each_link_from_a_warehouse_gets_its_percentage() -> void:
	var sim := _sim()
	var ends := _warehouse_two_way(sim)
	_set_split(sim, {ends[1]: 75, ends[2]: 25})

	sim.tick(300_000)

	var shipped := _shipped(sim, [ends[1], ends[2]])
	assert_gt(shipped[0] + shipped[1], 200)
	assert_almost_eq(shipped[0], 3 * shipped[1], 4, "75% and 25%")


func test_a_split_across_a_warehouse_and_a_factory_fails() -> void:
	var sim := _sim()
	var ends := _warehouse_two_way(sim)
	var from_factory := _automate(sim, _link(sim, 1, &"cobble"))
	var before := sim.snapshot()

	_assert_fails(sim, sim.set_split({ends[1]: 50, from_factory: 50}), CommandResult.Reason.MIXED_SOURCES,
		"Link #%d does not start at Red warehouse #%d. A split is across the links of one color from one source." % [
			from_factory, ends[0]], before)


func test_a_prestige_clears_the_splits() -> void:
	var sim := _sim()
	var ids := _three_way(sim)
	_set_split(sim, {ids[0]: 100})
	assert_true(sim.buy_prism().ok)

	var result := sim.prestige()

	assert_true(result.ok, result.message)
	assert_eq(sim.splits().size(), 0)
	assert_eq(sim.links().size(), 0)
