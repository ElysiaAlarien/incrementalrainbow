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
	sim.add_production_line(4)
	sim.start_shipment(3)
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	sim.start_shipment(4)
	sim.start_shipment(1)
	sim.tick(1400)
	sim.start_shipment(1)
	# The sales saturate red and blue in millbrook.
	sim.buy_prism()
	sim.buy_prism()
	return sim


## The content of the rich game, with the mixed colors, drift, and saturation.
func _content() -> Content:
	return ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(700, 6, ContentFixture.demand_overrides())))


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
	assert_eq(loaded.links().size(), 4)
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
	assert_eq(sim.prisms().owned, 2, "the rich game has prisms")
	assert_eq(loaded.prisms().owned, 2)
	assert_eq(loaded.prisms().total_bought, 2)
	assert_true(loaded.prisms().next_price.equals(sim.prisms().next_price))
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
	_assert_link_change_fails(func(link: Dictionary) -> void: link.id = 5,
		"state.links[0].id: must be less than next_link_id (5)")


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


func test_a_link_of_an_unknown_kind_fails() -> void:
	_assert_link_change_fails(func(link: Dictionary) -> void: link.destination_kind = "warehouse",
		"state.links[0].destination_kind: must be one of market, factory, but it is \"warehouse\"")


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
		"state.factories[3].input_bays: 16 blue widgets are in the bay and on the way, but the bay holds 10")


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


func test_a_version_4_save_has_no_prisms_after_migration() -> void:
	var result := _load(FileAccess.get_file_as_string("res://tests/fixtures/saves/v4.json"))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.prisms().owned, 0)
	assert_eq(result.simulation.prisms().total_bought, 0)
	assert_eq(result.simulation.prisms().next_price.format(), str(ContentFixture.FIRST_PRISM_PRICE))
