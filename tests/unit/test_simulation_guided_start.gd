extends GutTest
## The guided start: a new game teaches the player to build a factory, make a
## link, start a shipment, and sell at a market. Each step moves on when the
## core sees the action, and the player can skip the guide at any step.

const SEED := 26
const MARKET := &"millbrook"
const Step := GuidedStartView.Step


func _content(starting_money: float = 100) -> Content:
	var colors := ContentFixture.mixed_colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": starting_money}),
		ContentFixture.markets_data(ContentFixture.PRICE, colors)))


func _sim(starting_money: float = 100) -> Simulation:
	return Simulation.new(_content(starting_money), SEED)


func _step(sim: Simulation) -> Step:
	return sim.guided_start().step


## A game at [param step], with each action before it done.
func _sim_at(step: Step) -> Simulation:
	var sim := _sim()
	if step > Step.BUILD_FACTORY:
		assert_true(sim.build_factory(&"red").ok)
		sim.tick(3000)
	if step > Step.MAKE_LINK:
		assert_true(sim.make_link(1, MARKET).ok)
	if step > Step.START_SHIPMENT:
		assert_true(sim.start_shipment(1).ok)
	if step > Step.SELL:
		sim.tick(ContentFixture.TRANSIT_TIME_MS)
	assert_eq(_step(sim), step)
	return sim


func test_a_new_game_starts_the_guided_start_at_its_first_step() -> void:
	var view := _sim().guided_start()

	assert_eq(view.step, Step.BUILD_FACTORY)
	assert_true(view.is_active())


func test_building_a_factory_moves_on_to_making_a_link() -> void:
	var sim := _sim()

	assert_true(sim.build_factory(&"blue").ok)

	assert_eq(_step(sim), Step.MAKE_LINK)


func test_a_command_that_fails_does_not_move_on() -> void:
	var sim := _sim(5)

	assert_false(sim.build_factory(&"red").ok, "too little money")

	assert_eq(_step(sim), Step.BUILD_FACTORY)


func test_a_link_to_a_market_moves_on_to_starting_a_shipment() -> void:
	var sim := _sim_at(Step.MAKE_LINK)

	assert_true(sim.make_link(1, MARKET).ok)

	assert_eq(_step(sim), Step.START_SHIPMENT)


func test_a_link_to_a_mixed_factory_does_not_move_on() -> void:
	# The guide teaches a sale, so the link must go to a market.
	var sim := _sim_at(Step.MAKE_LINK)
	assert_true(sim.build_factory(&"yellow").ok)
	assert_true(sim.build_factory(&"green").ok)

	assert_true(sim.make_factory_link(2, 3).ok)

	assert_eq(_step(sim), Step.MAKE_LINK)


func test_a_shipment_to_a_market_moves_on_to_selling() -> void:
	var sim := _sim_at(Step.START_SHIPMENT)

	assert_true(sim.start_shipment(1).ok)

	assert_eq(_step(sim), Step.SELL)


func test_a_shipment_that_fails_does_not_move_on() -> void:
	var sim := _sim()
	assert_true(sim.build_factory(&"red").ok)
	assert_true(sim.make_link(1, MARKET).ok)

	assert_false(sim.start_shipment(1).ok, "the output bay is empty")

	assert_eq(_step(sim), Step.START_SHIPMENT)


func test_an_automatic_start_counts_as_a_shipment() -> void:
	var sim := _sim_at(Step.START_SHIPMENT)

	assert_true(sim.buy_automatic_transport(1).ok)
	sim.tick(1)

	assert_eq(_step(sim), Step.SELL)


func test_the_sale_at_the_market_completes_the_guided_start() -> void:
	var sim := _sim_at(Step.SELL)

	sim.tick(ContentFixture.TRANSIT_TIME_MS - 1)
	assert_eq(_step(sim), Step.SELL, "the shipment is still on its way")
	sim.tick(1)

	var view := sim.guided_start()
	assert_eq(view.step, Step.DONE)
	assert_false(view.is_active())


func test_a_player_who_feeds_a_mixed_factory_first_still_completes_it() -> void:
	# The guide waits at the link step while the player feeds a mixed factory,
	# and moves on when the mixed factory links to a market.
	var sim := _sim_at(Step.MAKE_LINK)
	assert_true(sim.build_factory(&"yellow").ok)
	assert_true(sim.build_factory(&"blue").ok)
	assert_true(sim.build_factory(&"green").ok)
	assert_true(sim.make_factory_link(2, 4).ok)
	assert_true(sim.make_factory_link(3, 4).ok)
	sim.tick(3000)
	assert_true(sim.start_shipment(1).ok)
	assert_true(sim.start_shipment(2).ok)
	sim.tick(ContentFixture.TRANSIT_TIME_MS + 3000)
	assert_eq(_step(sim), Step.MAKE_LINK, "shipments to a mixed factory do not count")

	assert_true(sim.make_link(4, MARKET).ok)
	assert_true(sim.start_shipment(3).ok)
	sim.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_eq(_step(sim), Step.DONE)


func test_the_player_can_skip_at_each_step() -> void:
	for step: Step in [Step.BUILD_FACTORY, Step.MAKE_LINK, Step.START_SHIPMENT, Step.SELL]:
		var sim := _sim_at(step)

		var result := sim.skip_guided_start()

		assert_true(result.ok, "skip at %s" % Step.find_key(step))
		assert_eq(_step(sim), Step.SKIPPED)
		assert_false(sim.guided_start().is_active())


func test_a_skipped_guide_stays_skipped_after_the_actions() -> void:
	var sim := _sim()
	sim.skip_guided_start()

	assert_true(sim.build_factory(&"red").ok)
	sim.tick(3000)
	assert_true(sim.make_link(1, MARKET).ok)
	assert_true(sim.start_shipment(1).ok)
	sim.tick(ContentFixture.TRANSIT_TIME_MS)

	assert_eq(_step(sim), Step.SKIPPED)


func test_a_skip_after_the_end_fails_and_changes_nothing() -> void:
	for step: Step in [Step.DONE, Step.SKIPPED]:
		var sim := _sim_at(Step.SELL)
		if step == Step.DONE:
			sim.tick(ContentFixture.TRANSIT_TIME_MS)
		else:
			sim.skip_guided_start()
		var before := sim.snapshot()

		var result := sim.skip_guided_start()

		assert_false(result.ok)
		assert_eq(result.reason, CommandResult.Reason.GUIDED_START_OVER)
		assert_ne(result.message, "")
		assert_eq(sim.snapshot(), before)


func test_offline_progress_can_complete_the_guided_start() -> void:
	var sim := _sim_at(Step.SELL)

	sim.progress_offline(ContentFixture.TRANSIT_TIME_MS)

	assert_eq(_step(sim), Step.DONE)


func test_a_prestige_does_not_show_the_guided_start_again() -> void:
	for step: Step in [Step.DONE, Step.SKIPPED]:
		var sim := Simulation.new(_content(1000), SEED)
		if step == Step.DONE:
			assert_true(sim.build_factory(&"red").ok)
			sim.tick(3000)
			assert_true(sim.make_link(1, MARKET).ok)
			assert_true(sim.start_shipment(1).ok)
			sim.tick(ContentFixture.TRANSIT_TIME_MS)
		else:
			sim.skip_guided_start()
		assert_true(sim.buy_prism().ok)

		assert_true(sim.prestige().ok)

		assert_eq(_step(sim), step, "a prestige keeps the end of the guide")


func test_a_prestige_before_the_end_ends_the_guided_start() -> void:
	# A player who can prestige has played, and the next run has no factory or
	# link for a later step to point at.
	var sim := Simulation.new(_content(1000), SEED)
	assert_true(sim.build_factory(&"red").ok)
	assert_true(sim.buy_prism().ok)

	assert_true(sim.prestige().ok)

	assert_eq(_step(sim), Step.SKIPPED)


func test_changing_the_view_does_not_change_the_game() -> void:
	var sim := _sim()

	sim.guided_start().step = Step.DONE

	assert_eq(_step(sim), Step.BUILD_FACTORY)
