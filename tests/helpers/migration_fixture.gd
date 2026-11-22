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


## The migrations of [param list], for [method SaveCodec.decode].
static func set_of(list: Array[SaveMigration]) -> SaveMigrations:
	return SaveMigrations.new(list)
