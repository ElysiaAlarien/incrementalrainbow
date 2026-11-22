extends GutTest
## The market and forecast queries give the same results as before #55 made
## them faster, and asking for them does not change the game.


func test_the_queries_give_the_same_results_as_before() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QueryResults.FIXTURE_PATH))
	var actual := QueryResults.record()

	assert_eq(actual.keys(), expected.keys(), "the same queries")
	var changed := PackedStringArray()
	for label: String in expected:
		if actual.get(label) != expected[label]:
			changed.append(label)
	assert_eq(changed, PackedStringArray(), "queries with other results than before")


func test_a_game_with_queries_and_a_game_with_none_stay_the_same() -> void:
	var content := QueryResults.content()
	var asked := Simulation.new(content, QueryResults.SEED)
	var quiet := Simulation.new(content, QueryResults.SEED)
	for sim: Simulation in [asked, quiet]:
		var factory: int = sim.build_factory(&"red").value
		sim.buy_automatic_transport(sim.make_link(factory, &"millbrook").value)

	for step in 40:
		for ahead_ms: int in QueryResults.AHEADS_MS:
			asked.forecast(ahead_ms)
		asked.markets()
		asked.tick(1250)
		quiet.tick(1250)

	assert_eq(asked.snapshot(), quiet.snapshot(), "the same state")
	assert_eq(QueryResults.markets_text(asked.markets()), QueryResults.markets_text(quiet.markets()),
		"the same markets")
	for ahead_ms: int in QueryResults.AHEADS_MS:
		assert_eq(QueryResults.forecast_text(asked.forecast(ahead_ms)),
			QueryResults.forecast_text(quiet.forecast(ahead_ms)), "the same forecast %d ms ahead" % ahead_ms)
