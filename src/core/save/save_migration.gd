class_name SaveMigration
extends RefCounted
## One named change to the shape of the saved state. See ADR-0014.
##
## Each migration of the game is a file in [constant SaveMigrations.FOLDER]
## whose script extends this class. The file name, without ".gd", is the name
## of the migration. A save lists the names of the migrations that its state
## has, so do not rename a file after a save can list it.

## The name that a save lists. [SaveMigrations] sets it from the file name.
var name: StringName


## The names of the migrations that must run before this one. List each
## migration that made a value that [method apply] reads or changes.
func needs() -> Array[StringName]:
	return []


## Turns [param state], the state as parsed JSON, into the new shape, and
## returns it. It must not stop on damaged data, because the load checks the
## result.
func apply(state: Dictionary) -> Dictionary:
	return state
