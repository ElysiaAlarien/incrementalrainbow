extends GutTest
## Rules that hold for every command and tick: commands that are not allowed
## change nothing, and the simulation is deterministic.


func test_an_unknown_color_fails_with_a_reason_and_changes_nothing() -> void:
	var sim := Simulation.new(ContentFixture.make(), 1)
	sim.build_factory(&"red")
	sim.tick(1500)
	var before := sim.snapshot()

	var result := sim.build_factory(&"magenta")

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_COLOR)
	assert_string_contains(result.message, "magenta")
	assert_eq(sim.snapshot(), before)


func test_a_color_with_a_recipe_cannot_be_built_as_a_base_factory() -> void:
	var colors := ContentFixture.colors_data()
	colors.colors.append({"id": "green", "name": "Green", "symbol": "diamond",
		"display": "#3a9a4a", "recipe": {"yellow": 1, "blue": 1}})
	var content := Content.from_data(ContentFixture.data(colors))
	var sim := Simulation.new(content, 1)
	var before := sim.snapshot()

	var result := sim.build_factory(&"green")

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_A_BASE_COLOR)
	assert_eq(sim.snapshot(), before)
	assert_false(sim.buildable_factory_colors().has(&"green"))


func _play(seed: int) -> Simulation:
	var sim := Simulation.new(ContentFixture.make(700, 6), seed)
	sim.build_factory(&"red")
	sim.tick(1234)
	sim.build_factory(&"blue")
	sim.build_factory(&"purple")
	sim.tick(5000)
	sim.build_factory(&"yellow")
	sim.tick(333)
	return sim


func test_the_same_seed_commands_and_ticks_give_the_same_state() -> void:
	assert_eq(_play(42).snapshot(), _play(42).snapshot())


func test_the_seed_is_part_of_the_state() -> void:
	assert_ne(_play(42).snapshot(), _play(43).snapshot())


func test_one_long_tick_gives_the_same_state_as_many_short_ticks() -> void:
	var one := Simulation.new(ContentFixture.make(700, 50), 9)
	var many := Simulation.new(ContentFixture.make(700, 50), 9)
	one.build_factory(&"red")
	many.build_factory(&"red")

	one.tick(20_000)
	for i in 200:
		many.tick(100)

	assert_eq(one.snapshot(), many.snapshot())


func test_the_core_runs_with_no_scene_tree() -> void:
	# Every core script must work outside the scene tree: none may be a Node.
	for path in _scripts_in("res://src/core"):
		var script: Script = load(path)
		var base := script.get_instance_base_type()
		assert_false(ClassDB.is_parent_class(base, &"Node"), "%s extends %s" % [path, base])


func _scripts_in(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts_in(dir_path.path_join(sub)))
	return found
