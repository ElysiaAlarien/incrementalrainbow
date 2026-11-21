extends GutTest
## The save: a versioned, serialized form of the core state (see ADR-0009).


## A game where every part of the core state has a value that is not its
## default. When you add core state, give it a non-default value here, so that
## the round-trip tests fail if save or load forgets it.
func _rich_game() -> Simulation:
	var sim := Simulation.new(ContentFixture.make(700, 6), 77)
	sim.build_factory(&"red")
	sim.tick(1234)
	sim.build_factory(&"blue")
	sim.tick(5000)
	sim.build_factory(&"yellow")
	sim.tick(333)
	return sim


func _load(text: String, steps: Array[Callable] = SaveCodec.migrations()) -> LoadResult:
	return SaveCodec.decode(ContentFixture.make(700, 6), text, steps)


func test_save_then_load_gives_the_same_state() -> void:
	var sim := _rich_game()

	var result := _load(SaveCodec.encode(sim))

	assert_true(result.ok, result.message)
	var loaded := result.simulation
	assert_eq(loaded.time_ms(), sim.time_ms())
	assert_eq(loaded.factories().size(), 3)
	for i in sim.factories().size():
		var want := sim.factories()[i]
		var got := loaded.factories()[i]
		assert_eq(got.id, want.id)
		assert_eq(got.color, want.color)
		assert_eq(got.output_bay_count, want.output_bay_count)
		assert_eq(got.status, want.status)
	assert_eq(loaded.snapshot(), sim.snapshot())


func test_the_loaded_game_plays_on_the_same_as_the_saved_game() -> void:
	var sim := _rich_game()
	var loaded := _load(SaveCodec.encode(sim)).simulation

	for game in [sim, loaded]:
		game.build_factory(&"red")
		game.tick(98_765)

	assert_eq(loaded.snapshot(), sim.snapshot())


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
	assert_eq(result.simulation.time_ms(), 6567)
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

	var result := _load(text)

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.time_ms(), 6567)
	var factories := sim.factories()
	assert_eq(factories.size(), 3)
	assert_eq([factories[0].id, factories[0].color, factories[0].output_bay_count], [1, &"red", 6])
	assert_eq([factories[1].id, factories[1].color, factories[1].output_bay_count], [2, &"blue", 6])
	assert_eq([factories[2].id, factories[2].color, factories[2].output_bay_count], [3, &"yellow", 0])
	assert_true(factories[0].is_stopped())
	assert_false(factories[2].is_stopped())
	sim.tick(367)
	assert_eq(sim.factory(3).output_bay_count, 1, "the yellow factory kept its progress")
