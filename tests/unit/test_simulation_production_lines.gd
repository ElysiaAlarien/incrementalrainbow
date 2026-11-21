extends GutTest
## Production lines: the size of a factory, what a line costs, and how size
## changes output. Driven only through commands, tick, and queries.

const SEED := 777


## One widget each second for each line, an output bay of 100, 100 starting
## money, and a flat line cost of 10.
func _sim() -> Simulation:
	return Simulation.new(ContentFixture.make(1000, 100), SEED)


## Like [method _sim], with balance values from [param overrides].
func _sim_with(overrides: Dictionary, output_bay_capacity: int = 100) -> Simulation:
	var balance := ContentFixture.balance_data(1000, output_bay_capacity, overrides)
	return Simulation.new(ContentFixture.make_with_balance(balance), SEED)


func _build(sim: Simulation, color: StringName = &"red") -> int:
	var result := sim.build_factory(color)
	assert_true(result.ok, result.message)
	return result.value


func _add_line(sim: Simulation, id: int) -> void:
	var result := sim.add_production_line(id)
	assert_true(result.ok, result.message)


func test_a_new_factory_has_one_production_line() -> void:
	var sim := _sim()
	var id := _build(sim)
	assert_eq(sim.factory(id).size, 1)


func test_adding_a_production_line_makes_the_size_go_up_by_one() -> void:
	var sim := _sim()
	var id := _build(sim)

	var result := sim.add_production_line(id)

	assert_true(result.ok, result.message)
	assert_eq(result.value, 2, "the new size")
	assert_eq(sim.factory(id).size, 2)
	_add_line(sim, id)
	assert_eq(sim.factory(id).size, 3)


func test_a_line_is_added_only_to_its_own_factory() -> void:
	var sim := _sim()
	var first := _build(sim)
	var second := _build(sim, &"blue")
	_add_line(sim, second)
	assert_eq(sim.factory(first).size, 1)
	assert_eq(sim.factory(second).size, 2)


func test_a_factory_with_more_lines_makes_more_widgets_in_the_same_ticks() -> void:
	var sim := _sim()
	var one_line := _build(sim)
	var three_lines := _build(sim)
	_add_line(sim, three_lines)
	_add_line(sim, three_lines)

	sim.tick(4500)

	assert_eq(sim.factory(one_line).output_bay_count, 4)
	assert_eq(sim.factory(three_lines).output_bay_count, 13, "3 lines for 4.5 s")


func test_a_new_line_starts_to_work_at_once() -> void:
	var sim := _sim()
	var id := _build(sim)
	sim.tick(600)
	_add_line(sim, id)

	sim.tick(200)

	assert_eq(sim.factory(id).output_bay_count, 1, "600 + 2 * 200 line-ms is one widget")


func test_a_larger_factory_stops_when_its_output_bay_is_full() -> void:
	var sim := Simulation.new(ContentFixture.make(1000, 10), SEED)
	var id := _build(sim)
	for i in 3:
		_add_line(sim, id)

	sim.tick(2499)
	assert_eq(sim.factory(id).output_bay_count, 9)
	assert_false(sim.factory(id).is_stopped())
	sim.tick(1)
	assert_eq(sim.factory(id).output_bay_count, 10)
	assert_eq(sim.factory(id).status, FactoryView.Status.OUTPUT_BAY_FULL)


func test_a_very_long_tick_on_a_large_factory_fills_the_bay() -> void:
	var sim := _sim_with({"starting_money": 1.0e9, "production_line_cost": 1}, 10)
	var id := _build(sim)
	for i in 1000:
		_add_line(sim, id)

	sim.tick(1 << 60)

	assert_eq(sim.factory(id).output_bay_count, 10)


func test_one_long_tick_equals_many_short_ticks_with_lines() -> void:
	var one := Simulation.new(ContentFixture.make(700, 500), SEED)
	var many := Simulation.new(ContentFixture.make(700, 500), SEED)
	for sim in [one, many]:
		var id := _build(sim)
		_add_line(sim, id)
		_add_line(sim, id)

	one.tick(33_333)
	for i in 333:
		many.tick(100)
	many.tick(33)

	assert_eq(one.snapshot(), many.snapshot())


func test_a_production_line_costs_money() -> void:
	var sim := _sim()
	var id := _build(sim)
	assert_true(sim.money().equals(BigNumber.from_int(100)), "starting money")
	assert_true(sim.factory(id).next_line_cost.equals(BigNumber.from_int(10)))

	_add_line(sim, id)

	assert_true(sim.money().equals(BigNumber.from_int(90)), "money is %s" % sim.money())


func test_each_line_costs_more_than_the_one_before_it_when_cost_grows() -> void:
	var sim := _sim_with({"starting_money": 1000, "production_line_cost_growth": 2.0})
	var id := _build(sim)

	var costs: Array[float] = []
	for i in 3:
		costs.append(sim.factory(id).next_line_cost.to_float())
		_add_line(sim, id)

	assert_eq(costs, [10.0, 20.0, 40.0] as Array[float])
	assert_true(sim.money().equals(BigNumber.from_int(930)), "money is %s" % sim.money())


func test_line_costs_are_whole_numbers() -> void:
	var sim := _sim_with({"starting_money": 1.0e6, "production_line_cost_growth": 1.15})
	var id := _build(sim)
	var spent := 0.0
	for i in 20:
		var cost := sim.factory(id).next_line_cost.to_float()
		assert_eq(cost, floorf(cost), "line %d costs %s" % [i + 2, cost])
		spent += cost
		_add_line(sim, id)
	# BigNumber keeps about 15 significant digits (ADR-0005).
	assert_almost_eq(sim.money().to_float(), 1.0e6 - spent, 1e-6)


func test_with_too_little_money_adding_a_line_fails_and_changes_nothing() -> void:
	var sim := _sim_with({"starting_money": 15})
	var id := _build(sim)
	_add_line(sim, id)
	sim.tick(1500)
	var before := sim.snapshot()

	var result := sim.add_production_line(id)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_MONEY)
	assert_string_contains(result.message, "10")
	assert_eq(sim.snapshot(), before)
	assert_eq(sim.factory(id).size, 2)


func test_exactly_enough_money_is_enough() -> void:
	var sim := _sim_with({"starting_money": 10})
	var id := _build(sim)

	_add_line(sim, id)

	assert_true(sim.money().is_zero())


func test_adding_a_line_to_an_unknown_factory_fails_and_changes_nothing() -> void:
	var sim := _sim()
	_build(sim)
	var before := sim.snapshot()

	var result := sim.add_production_line(99)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_FACTORY)
	assert_string_contains(result.message, "99")
	assert_eq(sim.snapshot(), before)


func test_size_and_money_are_part_of_the_state() -> void:
	var with_line := _sim()
	var without := _sim()
	_add_line(with_line, _build(with_line))
	_build(without)
	assert_ne(with_line.snapshot(), without.snapshot())


func test_a_factory_view_does_not_change_the_simulation() -> void:
	var sim := _sim()
	var id := _build(sim)
	var view := sim.factory(id)
	view.size = 50
	assert_eq(sim.factory(id).size, 1)
