class_name MigrationFixture
extends SaveMigration
## A migration for tests, made from a callable, so that a test does not need a
## file in [constant SaveMigrations.FOLDER].

var _needs: Array[StringName]
var _apply: Callable


func _init(p_name: StringName, p_apply: Callable = func(state: Dictionary) -> Dictionary: return state,
		p_needs: Array[StringName] = []) -> void:
	name = p_name
	_apply = p_apply
	_needs = p_needs


func needs() -> Array[StringName]:
	return _needs


func apply(state: Dictionary) -> Dictionary:
	return _apply.call(state)


## The migrations of the game and [param later]. Each one of [param later]
## that needs nothing gets the need of a later migration of the game: the last
## numbered migration.
static func after_the_game(later: Array[SaveMigration]) -> SaveMigrations:
	var last: Array[StringName] = [SaveCodec.NUMBERED_MIGRATIONS[-1]]
	var list := SaveMigrations.found().all()
	for migration in later:
		if migration is MigrationFixture and migration.needs().is_empty():
			(migration as MigrationFixture)._needs = last
		list.append(migration)
	return SaveMigrations.new(list)
