extends GutTest
## Base factories, driven only through the simulation's commands, tick, and queries.

const SEED := 12345

var content: Content


func before_each() -> void:
	# One widget each second, and an output bay of 10.
	content = TestContent.make(1000, 10)


func _build(sim: Simulation, color: StringName) -> int:
	var result := sim.build_factory(color)
	assert_true(result.ok, "build %s: %s" % [color, result.message])
	return result.value


func test_a_red_factory_makes_widgets_into_its_output_bay() -> void:
	var sim := Simulation.new(content, SEED)
	var id := _build(sim, &"red")

	sim.tick(3500)

	var factory := sim.factory(id)
	assert_eq(factory.color, &"red")
	assert_eq(factory.output_bay_count, 3)
	assert_eq(factory.status, FactoryView.Status.RUNNING)
	assert_false(factory.is_stopped())


func test_partial_progress_carries_over_to_the_next_tick() -> void:
	var sim := Simulation.new(content, SEED)
	var id := _build(sim, &"yellow")

	sim.tick(600)
	assert_eq(sim.factory(id).output_bay_count, 0)
	sim.tick(600)
	assert_eq(sim.factory(id).output_bay_count, 1)


func test_a_factory_stops_when_its_output_bay_is_full() -> void:
	var sim := Simulation.new(content, SEED)
	var id := _build(sim, &"blue")

	sim.tick(9999)
	assert_false(sim.factory(id).is_stopped(), "9 widgets, not full yet")

	sim.tick(1)
	var factory := sim.factory(id)
	assert_eq(factory.output_bay_count, 10)
	assert_eq(factory.output_bay_capacity, 10)
	assert_eq(factory.status, FactoryView.Status.OUTPUT_BAY_FULL)
	assert_true(factory.is_stopped())


func test_a_stopped_factory_makes_nothing_more() -> void:
	var sim := Simulation.new(content, SEED)
	var id := _build(sim, &"red")

	sim.tick(60 * 60 * 1000)

	assert_eq(sim.factory(id).output_bay_count, 10)


func test_each_factory_makes_widgets_on_its_own() -> void:
	var sim := Simulation.new(content, SEED)
	var first := _build(sim, &"red")
	sim.tick(2000)
	var second := _build(sim, &"red")
	sim.tick(2000)

	assert_ne(first, second)
	assert_eq(sim.factory(first).output_bay_count, 4)
	assert_eq(sim.factory(second).output_bay_count, 2)
	var ids: Array[int] = []
	for view in sim.factories():
		ids.append(view.id)
	assert_eq(ids, [first, second] as Array[int], "factories in build order")


func test_time_advances_by_each_tick() -> void:
	var sim := Simulation.new(content, SEED)
	sim.tick(250)
	sim.tick(1000)
	assert_eq(sim.time_ms(), 1250)


func test_the_base_colors_can_be_built() -> void:
	var sim := Simulation.new(content, SEED)
	assert_eq(sim.buildable_factory_colors(), [&"red", &"yellow", &"blue"] as Array[StringName])


func test_an_unknown_factory_id_gives_null() -> void:
	var sim := Simulation.new(content, SEED)
	assert_null(sim.factory(1))
