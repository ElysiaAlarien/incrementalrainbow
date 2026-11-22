extends SaveMigration
## Save version 13 (#22) adds the save time, beside the state (see
## [constant SaveCodec.SAVE_TIME_VERSION]). The state does not change. A save
## of an older version has no save time, so it loads with no offline progress.
##
## This is the last migration of the numbered save versions. Each later
## migration needs it, directly or through other migrations, so that it runs
## after all of them (see ADR-0014).


func needs() -> Array[StringName]:
	return [&"add_splits"]
