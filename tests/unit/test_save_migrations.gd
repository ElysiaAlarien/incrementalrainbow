extends GutTest
## The named migrations of the save and their run order (see ADR-0014).

const FIXTURES := "res://tests/fixtures/saves/"


func _names(migrations: SaveMigrations) -> Array[String]:
	var names: Array[String] = []
	for migration_name in migrations.names():
		names.append(String(migration_name))
	return names


static func _writes(key: String, value: Variant) -> Callable:
	return func(state: Dictionary) -> Dictionary:
		state[key] = value
		return state


# --- The migrations of the game -------------------------------------------------

func test_the_migrations_of_the_game_have_no_problems() -> void:
	assert_eq(SaveMigrations.found().problems(), PackedStringArray())


func test_each_numbered_migration_is_a_file_and_needs_the_one_before_it() -> void:
	var migrations := SaveMigrations.found()
	var names := migrations.names()
	for i in SaveCodec.NUMBERED_MIGRATIONS.size():
		var migration_name := SaveCodec.NUMBERED_MIGRATIONS[i]
		var migration := _migration(migrations, migration_name)
		assert_not_null(migration, "%s is a file" % migration_name)
		if migration == null:
			continue
		var expected: Array[StringName] = []
		if i > 0:
			expected.append(SaveCodec.NUMBERED_MIGRATIONS[i - 1])
		assert_eq(migration.needs(), expected, migration_name)
		if i > 0:
			assert_gt(names.find(migration_name), names.find(expected[0]), "%s runs after %s" % [
				migration_name, expected[0]])


## A later migration runs after all the numbered migrations, so a save of an
## old version gets it last, on the shape of the state that it expects.
func test_each_later_migration_needs_the_last_numbered_migration() -> void:
	var migrations := SaveMigrations.found()
	var last := SaveCodec.NUMBERED_MIGRATIONS[-1]
	for migration_name in migrations.names():
		if not SaveCodec.NUMBERED_MIGRATIONS.has(migration_name):
			assert_true(migrations.all_needs(migration_name).has(last),
				"%s needs %s, directly or through other migrations" % [migration_name, last])
	pass_test("each later migration needs %s" % last)


# --- Run order ------------------------------------------------------------------

func test_migrations_that_need_nothing_run_by_name() -> void:
	var list: Array[SaveMigration] = [MigrationFixture.new(&"cyan"), MigrationFixture.new(&"amber"),
		MigrationFixture.new(&"blue")]

	assert_eq(_names(SaveMigrations.new(list)), ["amber", "blue", "cyan"] as Array[String])


func test_a_migration_runs_after_the_migrations_it_needs() -> void:
	var list: Array[SaveMigration] = [
		MigrationFixture.new(&"amber", _writes("a", 1), [&"zinc"] as Array[StringName]),
		MigrationFixture.new(&"zinc"),
		MigrationFixture.new(&"moss", _writes("m", 1), [&"amber"] as Array[StringName]),
		MigrationFixture.new(&"blue"),
	]

	assert_eq(_names(SaveMigrations.new(list)), ["blue", "zinc", "amber", "moss"] as Array[String])


func test_the_run_order_does_not_depend_on_the_order_of_the_files() -> void:
	var make := func() -> Array[SaveMigration]:
		var list: Array[SaveMigration] = [
			MigrationFixture.new(&"d", _writes("d", 1), [&"b"] as Array[StringName]),
			MigrationFixture.new(&"b"),
			MigrationFixture.new(&"c", _writes("c", 1), [&"a"] as Array[StringName]),
			MigrationFixture.new(&"a"),
			MigrationFixture.new(&"e", _writes("e", 1), [&"c", &"d"] as Array[StringName]),
		]
		return list
	var expected := _names(SaveMigrations.new(make.call()))
	var list: Array[SaveMigration] = make.call()
	for i in 10:
		if i % 2 == 0:
			list.reverse()
		else:
			list.push_back(list.pop_front())
		assert_eq(_names(SaveMigrations.new(list)), expected)
	assert_eq(expected, ["a", "b", "c", "d", "e"] as Array[String])


func test_missing_gives_the_migrations_that_are_not_applied_in_run_order() -> void:
	var list: Array[SaveMigration] = [MigrationFixture.new(&"c"), MigrationFixture.new(&"a"),
		MigrationFixture.new(&"b")]
	var migrations := SaveMigrations.new(list)

	var missing := migrations.missing([&"b"] as Array[StringName])

	assert_eq(missing.map(func(m: SaveMigration) -> StringName: return m.name), [&"a", &"c"])


func test_a_need_that_is_not_a_migration_is_a_problem() -> void:
	var list: Array[SaveMigration] = [MigrationFixture.new(&"a", _writes("a", 1), [&"gone"] as Array[StringName])]

	assert_eq(SaveMigrations.new(list).problems(), PackedStringArray(["a needs gone, which is not a migration"]))


func test_migrations_that_need_each_other_are_a_problem() -> void:
	var list: Array[SaveMigration] = [
		MigrationFixture.new(&"a", _writes("a", 1), [&"b"] as Array[StringName]),
		MigrationFixture.new(&"b", _writes("b", 1), [&"a"] as Array[StringName]),
		MigrationFixture.new(&"c"),
	]
	var migrations := SaveMigrations.new(list)

	assert_eq(migrations.problems(), PackedStringArray(["these migrations need each other in a loop: a, b"]))
	assert_eq(_names(migrations), ["c"] as Array[String])


func test_two_migrations_with_one_name_are_a_problem() -> void:
	var list: Array[SaveMigration] = [MigrationFixture.new(&"a"), MigrationFixture.new(&"a")]

	assert_eq(SaveMigrations.new(list).problems(), PackedStringArray(["two migrations are named a"]))


# --- Independent migrations -----------------------------------------------------

## The pairs of migrations of which neither needs the other.
func _independent_pairs(migrations: SaveMigrations) -> Array[Array]:
	var names := migrations.names()
	var pairs: Array[Array] = []
	for i in names.size():
		for j in range(i + 1, names.size()):
			if not migrations.all_needs(names[i]).has(names[j]) and not migrations.all_needs(names[j]).has(names[i]):
				pairs.append([names[i], names[j]])
	return pairs


func _migration(migrations: SaveMigrations, migration_name: StringName) -> SaveMigration:
	for migration in migrations.missing([]):
		if migration.name == migration_name:
			return migration
	return null


## The state of [param data], a save, with each migration that it does not have
## except [param a], [param b], and the migrations that need them. Then
## [param a] and [param b] in both orders. Returns the two states as JSON.
func _both_orders(migrations: SaveMigrations, data: Dictionary, a: StringName, b: StringName) -> Array[String]:
	var applied: Array[StringName] = []
	if int(data.version) < SaveCodec.VERSION:
		applied = SaveCodec.NUMBERED_MIGRATIONS.slice(0, int(data.version) - 1)
	else:
		for migration_name: String in data.applied:
			applied.append(StringName(migration_name))
	var state: Dictionary = data.state.duplicate(true)
	for migration in migrations.missing(applied):
		var needs := migrations.all_needs(migration.name)
		if migration.name in [a, b] or needs.has(a) or needs.has(b):
			continue
		state = migration.apply(state)
	var a_then_b := _migration(migrations, b).apply(_migration(migrations, a).apply(state.duplicate(true)))
	var b_then_a := _migration(migrations, a).apply(_migration(migrations, b).apply(state.duplicate(true)))
	return [JSON.stringify(a_then_b, "", true), JSON.stringify(b_then_a, "", true)]


## Two migrations that do not need each other must give the same state in
## either order, from each saved fixture. When no two migrations are
## independent, the test has nothing to check. It can fail first on main, when
## two branches that each add a migration are both merged.
func test_independent_migrations_give_the_same_state_in_either_order() -> void:
	var migrations := SaveMigrations.found()
	var pairs := _independent_pairs(migrations)
	for file in DirAccess.get_files_at(FIXTURES):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + file))
		for pair in pairs:
			var states := _both_orders(migrations, data, pair[0], pair[1])
			assert_eq(states[0], states[1], "%s: %s and %s in either order" % [file, pair[0], pair[1]])
	pass_test("%d pairs of independent migrations" % pairs.size())


func test_the_order_check_passes_for_migrations_that_change_different_values() -> void:
	var list: Array[SaveMigration] = [MigrationFixture.new(&"a", _writes("a", 1)),
		MigrationFixture.new(&"b", _writes("b", 2))]
	var migrations := SaveMigrations.new(list)
	var data := {"version": SaveCodec.VERSION, "applied": [], "state": {"time_ms": 5}}

	assert_eq(_independent_pairs(migrations), [[&"a", &"b"]] as Array[Array])
	var states := _both_orders(migrations, data, &"a", &"b")
	assert_eq(states[0], states[1])


func test_the_order_check_finds_migrations_that_change_the_same_value() -> void:
	var list: Array[SaveMigration] = [MigrationFixture.new(&"a", _writes("x", 1)),
		MigrationFixture.new(&"b", _writes("x", 2))]
	var migrations := SaveMigrations.new(list)
	var data := {"version": SaveCodec.VERSION, "applied": [], "state": {}}

	var states := _both_orders(migrations, data, &"a", &"b")
	assert_ne(states[0], states[1], "the check sees that the order matters")


func test_the_order_check_runs_the_needs_of_the_pair_first() -> void:
	var list: Array[SaveMigration] = [
		MigrationFixture.new(&"base", _writes("links", [])),
		MigrationFixture.new(&"a", func(state: Dictionary) -> Dictionary:
			state.links.append("a")
			return state, [&"base"] as Array[StringName]),
		MigrationFixture.new(&"b", _writes("b", 1), [&"base"] as Array[StringName]),
	]
	var migrations := SaveMigrations.new(list)
	var data := {"version": SaveCodec.VERSION, "applied": [], "state": {}}

	var states := _both_orders(migrations, data, &"a", &"b")
	assert_eq(states[0], states[1])
	assert_eq(states[0], JSON.stringify({"b": 1, "links": ["a"]}, "", true))
