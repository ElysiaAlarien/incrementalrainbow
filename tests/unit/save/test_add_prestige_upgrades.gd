extends GutTest
## The migration add_prestige_upgrades (#20): the save lists the prestige
## upgrades that the player owns.

const FIXTURE := "res://tests/fixtures/saves/add_prestige_upgrades.json"
const OLDER_FIXTURE := "res://tests/fixtures/saves/v14.json"


func _load(text: String) -> LoadResult:
	return SaveCodec.decode(ContentFixture.make_for_saves(), text)


## The state of [constant FIXTURE], to change for a load that fails.
func _fixture_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func test_the_fixture_loads_with_its_prestige_upgrade() -> void:
	var result := _load(FileAccess.get_file_as_string(FIXTURE))

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_true(sim.prestige_upgrade(&"quick_lines").owned)
	assert_false(sim.prestige_upgrade(&"seed_money").owned)
	assert_eq([sim.prisms().owned, sim.prisms().total_bought], [0, 1], "the upgrade cost the prism")


func test_the_loaded_upgrade_still_has_its_effect() -> void:
	var sim := _load(FileAccess.get_file_as_string(FIXTURE)).simulation
	var factory: int = sim.build_factory(&"red").value

	# make_for_saves makes a widget each 700 ms, and quick_lines doubles the
	# speed.
	sim.tick(350)

	assert_eq(sim.factory(factory).output_bay_count, 1)


func test_an_older_save_has_no_prestige_upgrades() -> void:
	var result := _load(FileAccess.get_file_as_string(OLDER_FIXTURE))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.snapshot().prestige_upgrades, [])
	for view in result.simulation.prestige_upgrades():
		assert_false(view.owned, "%s is not owned" % view.id)


func test_an_unknown_prestige_upgrade_fails() -> void:
	var data := _fixture_data()
	data.state.prestige_upgrades.append("magic")

	var result := _load(JSON.stringify(data))

	assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE, result.message)
	assert_string_contains(result.message, "state.prestige_upgrades: there is no prestige upgrade \"magic\"")


func test_a_prestige_upgrade_twice_fails() -> void:
	var data := _fixture_data()
	data.state.prestige_upgrades.append("quick_lines")

	var result := _load(JSON.stringify(data))

	assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE, result.message)
	assert_string_contains(result.message, "state.prestige_upgrades: quick_lines is in the list more than once")


func test_a_save_with_no_list_fails() -> void:
	var data := _fixture_data()
	data.state.erase("prestige_upgrades")

	var result := _load(JSON.stringify(data))

	assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE, result.message)
	assert_string_contains(result.message, "state.prestige_upgrades: is missing")
