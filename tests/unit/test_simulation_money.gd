extends GutTest
## Money: a run starts with some, and building a factory costs some.

const SEED := 7


func _content(build_cost: float, starting_money: float) -> Content:
	return ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10,
		{"build_cost": build_cost, "starting_money": starting_money})))


func test_a_run_starts_with_the_starting_money() -> void:
	var sim := Simulation.new(_content(10, 45), SEED)
	assert_true(sim.money().equals(BigNumber.from_int(45)), "got %s" % sim.money())


func test_building_a_factory_costs_money() -> void:
	var sim := Simulation.new(_content(10, 45), SEED)
	assert_true(sim.factory_build_cost().equals(BigNumber.from_int(10)))

	assert_true(sim.build_factory(&"red").ok)

	assert_true(sim.money().equals(BigNumber.from_int(35)), "got %s" % sim.money())


func test_the_last_money_can_build_a_factory() -> void:
	var sim := Simulation.new(_content(10, 20), SEED)
	assert_true(sim.build_factory(&"red").ok)
	assert_true(sim.build_factory(&"blue").ok)
	assert_true(sim.money().is_zero(), "got %s" % sim.money())


func test_building_a_factory_with_too_little_money_fails_and_changes_nothing() -> void:
	var sim := Simulation.new(_content(10, 15), SEED)
	sim.build_factory(&"red")
	var before := sim.snapshot()

	var result := sim.build_factory(&"yellow")

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_MONEY)
	assert_string_contains(result.message, "10")
	assert_eq(sim.snapshot(), before)
	assert_eq(sim.factories().size(), 1)


func test_money_is_part_of_the_state() -> void:
	var a := Simulation.new(_content(10, 15), SEED)
	var b := Simulation.new(_content(10, 16), SEED)
	assert_ne(a.snapshot(), b.snapshot())
