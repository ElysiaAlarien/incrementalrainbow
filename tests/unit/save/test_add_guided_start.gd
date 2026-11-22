extends GutTest
## The save keeps the guided start (#26). An older save is from earlier play,
## so it loads with the guide done.

const FIXTURES := "res://tests/fixtures/saves/"
const SAVED_AT_UNIX_MS := 1_795_000_000_000


func _load(text: String) -> LoadResult:
	return SaveCodec.decode(ContentFixture.make_for_saves(), text)


func _fixture(file_name: String) -> LoadResult:
	return _load(FileAccess.get_file_as_string(FIXTURES + file_name))


## [param state] in a save of the game, with each migration applied.
func _save_of(state: Dictionary) -> String:
	var save: Dictionary = JSON.parse_string(SaveCodec.encode(
		Simulation.new(ContentFixture.make_for_saves(), 1), SAVED_AT_UNIX_MS))
	save.state.merge(state, true)
	return JSON.stringify(save)


## The state of a new game, as plain data.
func _new_state() -> Dictionary:
	return Simulation.new(ContentFixture.make_for_saves(), 1).snapshot()


func test_the_fixture_loads_at_its_step() -> void:
	var result := _fixture("add_guided_start.json")

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.guided_start().step, GuidedStartView.Step.START_SHIPMENT)


func test_an_older_save_loads_with_the_guide_done() -> void:
	var result := _fixture("v14.json")

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.guided_start().step, GuidedStartView.Step.DONE)


func test_each_step_round_trips() -> void:
	for step: GuidedStartView.Step in GuidedStartView.Step.values():
		var state := _new_state()
		state.guided_start = GuidedStartView.Step.find_key(step).to_lower()

		var result := _load(_save_of(state))

		assert_true(result.ok, result.message)
		assert_eq(result.simulation.guided_start().step, step)


func test_a_step_that_does_not_exist_fails() -> void:
	var state := _new_state()
	state.guided_start = "dance"

	var result := _load(_save_of(state))

	assert_false(result.ok)
	assert_string_contains(result.message, "state.guided_start")
