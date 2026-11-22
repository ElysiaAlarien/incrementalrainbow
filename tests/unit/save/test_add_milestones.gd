extends GutTest
## The save keeps the milestones (#25, ADR-0019). An older save gets each
## milestone that its state shows, and the first sale when a trace of a sale is
## in the state.

const FIXTURES := "res://tests/fixtures/saves/"
const SAVED_AT_UNIX_MS := 1_795_000_000_000


func _load(text: String) -> LoadResult:
	return SaveCodec.decode(ContentFixture.make_for_saves(), text)


func _fixture(file_name: String) -> LoadResult:
	return _load(FileAccess.get_file_as_string(FIXTURES + file_name))


## The save of [param file_name] with each value of [param state] in its state.
func _fixture_with(file_name: String, state: Dictionary) -> String:
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + file_name))
	save.state.merge(state, true)
	return JSON.stringify(save)


func test_the_fixture_loads_with_its_milestones() -> void:
	var result := _fixture("add_milestones.json")

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.milestones(), {
		&"factories": 3, &"factory.blue": 1, &"factory.red": 1, &"factory.yellow": 1,
		&"first_sale": 1, &"prestiges": 1, &"prisms_bought": 1,
	} as Dictionary[StringName, int])


func test_an_older_save_gets_the_milestones_that_its_state_shows() -> void:
	var result := _fixture("v14.json")
	assert_true(result.ok, result.message)
	var sim := result.simulation

	var milestones := sim.milestones()
	for view in sim.factories():
		assert_eq(milestones.get(Milestones.factory(view.color)), 1, String(view.color))
	assert_eq(milestones.get(Milestones.FACTORIES), sim.factories().size())
	assert_false(milestones.has(Milestones.PRESTIGES), "an older save has no count of prestiges")


func test_an_older_save_with_capacity_used_gets_the_first_sale() -> void:
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "v14.json"))
	save.state.saturation = []
	for market: Dictionary in save.state.markets:
		market.capacity_used = 0
	save.state.markets[0].capacity_used = 3

	var result := _load(JSON.stringify(save))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.milestones().get(Milestones.FIRST_SALE), 1)


func test_an_older_save_with_saturation_gets_the_first_sale() -> void:
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "v14.json"))
	for market: Dictionary in save.state.markets:
		market.capacity_used = 0
	save.state.saturation = [{"market_id": "millbrook", "color": "red",
		"saturated_until_ms": save.state.time_ms + 10_000}]

	var result := _load(JSON.stringify(save))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.milestones().get(Milestones.FIRST_SALE), 1)


func test_an_older_save_with_no_trace_of_a_sale_has_no_first_sale() -> void:
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "v14.json"))
	save.state.saturation = []
	for market: Dictionary in save.state.markets:
		market.capacity_used = 0

	var result := _load(JSON.stringify(save))

	assert_true(result.ok, result.message)
	assert_false(result.simulation.milestones().has(Milestones.FIRST_SALE))


func test_a_saved_milestone_above_what_the_state_shows_stays() -> void:
	var result := _load(_fixture_with("add_milestones.json",
		{"milestones": [{"id": "factories", "value": 40, "imported": 0}]}))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.milestones()[Milestones.FACTORIES], 40)


func test_an_older_save_has_no_imported_milestones() -> void:
	var result := _fixture("v14.json")
	assert_true(result.ok, result.message)

	assert_eq(result.simulation.imported_milestones(), {} as Dictionary[StringName, int],
		"an older game gets the achievements of its milestones")
