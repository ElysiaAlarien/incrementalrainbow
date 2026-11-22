extends GutTest
## The add_sell_thresholds migration (#15): each warehouse has a sell
## threshold, and an automatic link can be held.

const FIXTURES := "res://tests/fixtures/saves/"


func _load(file: String) -> Simulation:
	var result := SaveCodec.decode(ContentFixture.make_for_saves(),
		FileAccess.get_file_as_string(FIXTURES + file))
	assert_true(result.ok, result.message)
	return result.simulation


func test_a_save_keeps_sell_thresholds_and_a_held_link() -> void:
	var sim := _load("add_sell_thresholds.json")

	assert_eq(sim.warehouse(1).sell_threshold, 150)
	assert_eq(sim.warehouse(2).sell_threshold, 80)
	assert_eq(sim.link(2).automatic, LinkView.Automatic.HELD)
	assert_eq(sim.warehouse(1).held_market_ids, [&"millbrook"] as Array[StringName])
	assert_false(sim.warehouse(2).holds())


func test_a_warehouse_of_an_older_save_has_no_sell_threshold() -> void:
	var sim := _load("v10.json")

	assert_eq(sim.warehouse(1).sell_threshold, WarehouseView.NO_SELL_THRESHOLD)
	assert_false(sim.warehouse(1).holds())


func test_a_sell_threshold_of_0_is_damaged() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "add_sell_thresholds.json"))
	data.state.warehouses[0].sell_threshold = 0

	var result := SaveCodec.decode(ContentFixture.make_for_saves(), JSON.stringify(data))

	assert_false(result.ok)
	assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE)
	assert_string_contains(result.message, "state.warehouses[0].sell_threshold: must be -1 (none) or at least 1")
