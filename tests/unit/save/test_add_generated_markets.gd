extends GutTest
## The add_generated_markets migration (#12): the save keeps the count of
## generated markets. The load makes them again from the drift key, with their
## state from the save. The fixture is a game with
## [method ContentFixture.make_for_saves] content and seed 1212 that bought
## trucks, so it has three generated markets: it sold 4 red widgets in
## generated_1 and has more on the way there, and it made a community
## investment for income in generated_2.

const FIXTURE := "res://tests/fixtures/saves/add_generated_markets.json"
const SEED := 1212


func _load(text: String, content: Content = ContentFixture.make_for_saves()) -> LoadResult:
	return SaveCodec.decode(content, text)


func _fixture() -> Simulation:
	var result := _load(FileAccess.get_file_as_string(FIXTURE))
	assert_true(result.ok, result.message)
	return result.simulation


func _ids(sim: Simulation) -> Array[StringName]:
	var ids: Array[StringName] = []
	for view in sim.markets():
		ids.append(view.id)
	return ids


func test_saving_and_loading_keeps_generated_markets() -> void:
	var sim := _fixture()

	assert_eq(_ids(sim), [&"millbrook", &"generated_1", &"generated_2", &"generated_3"] as Array[StringName])
	assert_eq(sim.market(&"generated_1").capacity_used, 4)
	assert_gt(sim.market(&"generated_1").capacity_in_transit, 0)
	assert_eq(sim.market(&"generated_2").income, 149, "the income after one community investment")
	assert_eq(sim.link(1).destination_market_id, &"generated_1")


func test_the_loaded_markets_are_the_markets_of_the_saved_game() -> void:
	var sim := _fixture()
	var played := Simulation.new(ContentFixture.make_for_saves(), SEED)
	assert_true(played.buy_transport_tier().ok)

	for id: StringName in [&"generated_1", &"generated_2", &"generated_3"]:
		assert_eq([sim.market(id).name, sim.market(id).remoteness],
			[played.market(id).name, played.market(id).remoteness], String(id))


func test_save_then_load_of_the_fixture_gives_the_same_state() -> void:
	var sim := _fixture()

	var again := _load(SaveCodec.encode(sim, 1))

	assert_true(again.ok, again.message)
	assert_eq(again.simulation.snapshot(), sim.snapshot())


func test_the_loaded_game_sells_in_a_generated_market() -> void:
	var sim := _fixture()
	var before := sim.money()

	sim.tick(ContentFixture.TRUCK_TRANSIT_TIME_MS)

	assert_true(sim.money().is_greater_than(before), "the shipment to generated_1 sells")


func test_an_older_save_gets_the_generated_markets_of_a_new_game() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/v14.json")

	var result := _load(text)

	assert_true(result.ok, result.message)
	var sim := result.simulation
	assert_eq(sim.transport_tier().id, &"cart")
	assert_eq(sim.snapshot().generated_markets, 1, "carts reach no generated market, and the game shows 1 closed market")
	var start := ContentFixture.make_for_saves().market_generator.generate(sim.snapshot().drift_key, 1)
	assert_eq([sim.market(&"generated_1").name, sim.market(&"generated_1").population],
		[start.name, start.start_population], "the market from the drift key of the save")
	assert_eq(sim.market(&"generated_1").capacity_used, 0)
	assert_eq(sim.market(&"generated_1").income_investment_cost.to_data(),
		ContentFixture.make_for_saves().market_balance.investment_cost.to_data(), "no community investments")


func test_the_migration_gives_an_older_save_no_generated_markets() -> void:
	var migration: SaveMigration = load("res://src/core/save/migrations/add_generated_markets.gd").new()

	assert_eq(migration.apply({"time_ms": 5}), {"time_ms": 5, "generated_markets": 0})


func test_generated_markets_with_content_that_has_no_generator_fail() -> void:
	var result := _load(FileAccess.get_file_as_string(FIXTURE), ContentFixture.make_mixed(700, 6))

	assert_false(result.ok)
	assert_eq(result.reason, LoadResult.Reason.DAMAGED_STATE)
	assert_string_contains(result.message, "state.generated_markets: the content has no market generator")


func test_a_link_to_a_generated_market_that_the_save_does_not_have_fails() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	data.state.links[0].destination_market_id = "generated_9"

	var result := _load(JSON.stringify(data))

	assert_false(result.ok)
	assert_string_contains(result.message, "state.links[0].destination_market_id: there is no market \"generated_9\"")


func test_a_negative_count_of_generated_markets_fails() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	data.state.generated_markets = -1

	var result := _load(JSON.stringify(data))

	assert_false(result.ok)
	assert_string_contains(result.message, "state.generated_markets")
