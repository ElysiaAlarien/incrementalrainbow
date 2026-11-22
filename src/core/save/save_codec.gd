class_name SaveCodec
extends RefCounted
## Turns the core state into save text and back. See ADR-0009 and ADR-0014.
##
## A save is JSON:
## [code]{"format": FORMAT, "version": VERSION, "applied": [...],
## "saved_at_unix_ms": T, "state": {...}}[/code].
## The state is [method Simulation.snapshot]. The save time T is the device
## clock time that the state is for, in Unix milliseconds. It is beside the
## state, not in it, because the core has no clock. A load makes a new
## [Simulation] and never changes the current one.
##
## "applied" lists the names of the migrations that the state has. Each change
## to the shape of the state (a value added, removed, renamed, or changed in
## meaning) adds one [SaveMigration] file to [constant SaveMigrations.FOLDER].
## A load runs each migration that the save does not list, so old saves still
## load, and a save that lists a migration that the game does not know fails.

const FORMAT := "incremental-rainbow-save"
## The version of the save format. Saves of versions 1 to 13 had a version
## number for each change to the state and no "applied" list (see
## [constant NUMBERED_MIGRATIONS]). From version 14, the "applied" list tells
## the changes, and the version changes only when the format around the state
## changes. A game of version 13 or older reads a version 14 save as a save of
## a newer game.
const VERSION := 14
## The start of the message of a save of a newer game. [ExportCode] changes
## "save" to "export code" in it.
const NEWER_SAVE := "A newer version of the game made this save"
## The first save version with a save time. An older save has none.
const SAVE_TIME_VERSION := 13
## The migrations of the numbered save versions, in order. A save of version
## [code]N[/code] below [constant VERSION] has the first [code]N - 1[/code] of
## them. Do not change this list: a new migration is a new file only.
const NUMBERED_MIGRATIONS: Array[StringName] = [&"add_links", &"add_automatic_transport",
	&"add_demand", &"add_prisms", &"add_mixed_factories", &"add_demand_events", &"add_markets",
	&"add_warehouses", &"add_transport_tier", &"add_research", &"add_splits", &"add_save_time"]


## The save text of the current state of [param sim], which is the state at
## the device clock time [param saved_at_unix_ms]. [param migrations] is for
## tests; the game uses the default.
static func encode(sim: Simulation, saved_at_unix_ms: int,
		migrations: SaveMigrations = SaveMigrations.found()) -> String:
	return JSON.stringify({
		"format": FORMAT,
		"version": VERSION,
		"applied": migrations.names(),
		"saved_at_unix_ms": saved_at_unix_ms,
		"state": sim.snapshot(),
	}, "\t", true, true)


## Loads [param text] into a new simulation with [param content]. Each
## migration that the save does not list runs first, in run order.
## [param migrations] is for tests; the game uses the default.
static func decode(content: Content, text: String,
		migrations: SaveMigrations = SaveMigrations.found()) -> LoadResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return LoadResult.failure(LoadResult.Reason.NOT_JSON,
			"The save is damaged: it is not valid JSON (line %d: %s)." % [
				json.get_error_line() + 1, json.get_error_message()])
	var data: Variant = json.data
	if not data is Dictionary or data.get("format") != FORMAT:
		return LoadResult.failure(LoadResult.Reason.NOT_A_SAVE,
			"This is not a save of Incremental Rainbow.")

	var envelope := SnapshotReader.new(data, "save")
	var version := envelope.integer("version", 1)
	if not envelope.errors().is_empty():
		return LoadResult.failure(LoadResult.Reason.BAD_VERSION,
			"The save is damaged: %s." % envelope.errors()[0])
	if version > VERSION:
		return LoadResult.failure(LoadResult.Reason.NEWER_VERSION,
			"%s (save version %d). This version reads saves up to version %d." % [
				NEWER_SAVE, version, VERSION])
	var applied := _applied(envelope, version)
	if not envelope.errors().is_empty():
		return LoadResult.failure(LoadResult.Reason.BAD_VERSION,
			"The save is damaged: %s." % envelope.errors()[0])
	var unknown: Array[String] = []
	for migration_name in applied:
		if not migrations.has(migration_name):
			unknown.append(String(migration_name))
	if not unknown.is_empty():
		return LoadResult.failure(LoadResult.Reason.NEWER_VERSION,
			"%s. It has changes that this version does not know: %s." % [
				NEWER_SAVE, ", ".join(unknown)])
	for migration_name in applied:
		for need in migrations.all_needs(migration_name):
			if not applied.has(need):
				return LoadResult.failure(LoadResult.Reason.BAD_VERSION,
					"The save is damaged: save.applied: %s needs %s, which the list does not have." % [
						migration_name, need])
	var saved_at_unix_ms := LoadResult.NO_SAVE_TIME
	if version >= SAVE_TIME_VERSION:
		saved_at_unix_ms = envelope.integer("saved_at_unix_ms", 0)
		if not envelope.errors().is_empty():
			return LoadResult.failure(LoadResult.Reason.DAMAGED_STATE,
				"The save is damaged: %s." % envelope.errors()[0])

	var state: Variant = data.get("state")
	var to_run := migrations.missing(applied)
	for migration in to_run:
		if not state is Dictionary:
			break
		state = migration.apply(state)
	var migrated := not to_run.is_empty()
	if not state is Dictionary:
		return _damaged("The save is damaged: state: must be an object.", migrated)

	var reader := SnapshotReader.new(state)
	var sim := Simulation.from_snapshot(content, reader)
	var problems := reader.errors()
	if not problems.is_empty():
		var more := "" if problems.size() == 1 else " (and %d more problems)" % (problems.size() - 1)
		return _damaged("The save is damaged: %s%s." % [problems[0], more], migrated)
	var result := LoadResult.success(sim, saved_at_unix_ms)
	result.migrated = migrated
	return result


## The names of the migrations that a save of [param version] has. A save of a
## numbered version has no list. Problems go to [param envelope].
static func _applied(envelope: SnapshotReader, version: int) -> Array[StringName]:
	if version < VERSION:
		return NUMBERED_MIGRATIONS.slice(0, version - 1)
	var applied := envelope.text_id_list("applied")
	var seen: Array[StringName] = []
	for migration_name in applied:
		if seen.has(migration_name):
			envelope.fail("applied", "lists %s twice" % migration_name)
		seen.append(migration_name)
	return applied


static func _damaged(message: String, migrated: bool) -> LoadResult:
	var result := LoadResult.failure(LoadResult.Reason.DAMAGED_STATE, message)
	result.migrated = migrated
	return result
