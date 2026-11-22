class_name SaveMigrations
extends RefCounted
## The migrations that the game knows, and the order to run them. See ADR-0014.
##
## [method found] reads each script in [constant FOLDER], so a new migration is
## a new file and no shared list changes. The run order respects
## [method SaveMigration.needs]. Between migrations that do not need each other,
## the order is by name, so a load always runs the same steps in the same order.

const FOLDER := "res://src/core/save/migrations/"

static var _found: SaveMigrations

var _by_name: Dictionary[StringName, SaveMigration] = {}
var _order: Array[StringName] = []
var _problems := PackedStringArray()


## The migrations in [constant FOLDER]. The game reads the folder once. Each
## problem in the folder is an engine error, and [method problems] lists it.
static func found() -> SaveMigrations:
	if _found == null:
		var list: Array[SaveMigration] = []
		var problems := PackedStringArray()
		# list_directory also works in an exported game, where the scripts are
		# remapped.
		for file in ResourceLoader.list_directory(FOLDER):
			if not file.ends_with(".gd"):
				continue
			var script: Variant = load(FOLDER + file)
			var migration: Variant = script.new() if script is GDScript and script.can_instantiate() else null
			if not migration is SaveMigration:
				problems.append("%s does not extend SaveMigration" % file)
				continue
			migration.name = StringName(file.get_basename())
			list.append(migration)
		_found = SaveMigrations.new(list, problems)
		for problem in _found.problems():
			push_error("Save migrations: %s." % problem)
	return _found


## The migrations in [param list], each with its [member SaveMigration.name]
## set. [param p_problems] are problems that the caller found before.
func _init(list: Array[SaveMigration], p_problems := PackedStringArray()) -> void:
	_problems = p_problems.duplicate()
	for migration in list:
		if _by_name.has(migration.name):
			_problems.append("two migrations are named %s" % migration.name)
			continue
		_by_name[migration.name] = migration
	for migration: SaveMigration in _by_name.values():
		for need in migration.needs():
			if not _by_name.has(need):
				_problems.append("%s needs %s, which is not a migration" % [migration.name, need])
	_order = _sorted()


## Each mistake in the migrations, such as a need that is not a migration or
## migrations that need each other. A test keeps this empty for the game.
func problems() -> PackedStringArray:
	return _problems


## The names of all the migrations, in run order. A new save lists them.
func names() -> Array[StringName]:
	return _order.duplicate()


func has(migration_name: StringName) -> bool:
	return _by_name.has(migration_name)


## The migrations that [param migration_name] needs directly and through
## other migrations.
func all_needs(migration_name: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	var to_visit: Array[StringName] = [migration_name]
	while not to_visit.is_empty():
		var current: StringName = to_visit.pop_back()
		if not _by_name.has(current):
			continue
		for need in _by_name[current].needs():
			if not found.has(need):
				found.append(need)
				to_visit.append(need)
	return found


## The migrations that are not in [param applied], in run order.
func missing(applied: Array[StringName]) -> Array[SaveMigration]:
	var result: Array[SaveMigration] = []
	for migration_name in _order:
		if not applied.has(migration_name):
			result.append(_by_name[migration_name])
	return result


## The run order: each migration after the migrations it needs, and by name
## when no need decides.
func _sorted() -> Array[StringName]:
	var unmet: Dictionary[StringName, int] = {}
	var needed_by: Dictionary[StringName, Array] = {}
	for migration: SaveMigration in _by_name.values():
		unmet[migration.name] = 0
		for need in migration.needs():
			if _by_name.has(need):
				unmet[migration.name] += 1
				if not needed_by.has(need):
					needed_by[need] = []
				needed_by[need].append(migration.name)
	var ready: Array[StringName] = []
	for migration_name in unmet:
		if unmet[migration_name] == 0:
			ready.append(migration_name)
	var order: Array[StringName] = []
	while not ready.is_empty():
		ready.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		var next: StringName = ready.pop_front()
		order.append(next)
		for dependent: StringName in needed_by.get(next, []):
			unmet[dependent] -= 1
			if unmet[dependent] == 0:
				ready.append(dependent)
	if order.size() < unmet.size():
		var stuck: Array[String] = []
		for migration_name in unmet:
			if not order.has(migration_name):
				stuck.append(String(migration_name))
		stuck.sort()
		_problems.append("these migrations need each other in a loop: %s" % ", ".join(stuck))
	return order
