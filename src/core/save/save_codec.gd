class_name SaveCodec
extends RefCounted
## Turns the core state into save text and back. See ADR-0009.
##
## A save is JSON: [code]{"format": FORMAT, "version": N, "state": {...}}[/code].
## The state is [method Simulation.snapshot]. A load makes a new [Simulation]
## and never changes the current one.
##
## Each change to the shape of the state (a value added, removed, renamed, or
## changed in meaning) adds one step to [method migrations]. The step turns the
## state of the version before it into the new shape, so old saves still load.
## The version number is the number of steps plus one.

const FORMAT := "incremental-rainbow-save"


## The migration steps, in order. Step [code]i[/code] turns the state of
## version [code]i + 1[/code] into the state of version [code]i + 2[/code]. A
## step gets the state as parsed JSON and returns the new state. It must not
## stop on damaged data, because the load checks the result.
static func migrations() -> Array[Callable]:
	return [_v1_add_links]


## Version 2 (#3) adds links and their shipments. A version 1 game had none.
static func _v1_add_links(state: Dictionary) -> Dictionary:
	state.next_link_id = 1
	state.links = []
	state.next_shipment_id = 1
	return state


## The version that [method encode] writes.
static func current_version(steps: Array[Callable] = migrations()) -> int:
	return steps.size() + 1


## The save text of the current state of [param sim].
static func encode(sim: Simulation) -> String:
	return JSON.stringify({
		"format": FORMAT,
		"version": current_version(),
		"state": sim.snapshot(),
	}, "\t", true, true)


## Loads [param text] into a new simulation with [param content]. A save of an
## older version is migrated first. [param steps] is for tests; the game uses
## the default.
static func decode(content: Content, text: String, steps: Array[Callable] = migrations()) -> LoadResult:
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
	var current := current_version(steps)
	if version > current:
		return LoadResult.failure(LoadResult.Reason.NEWER_VERSION,
			"A newer version of the game made this save (save version %d). This version reads saves up to version %d." % [
				version, current])

	var state: Variant = data.get("state")
	for from_version in range(version, current):
		if not state is Dictionary:
			break
		state = steps[from_version - 1].call(state)
	if not state is Dictionary:
		return LoadResult.failure(LoadResult.Reason.DAMAGED_STATE,
			"The save is damaged: state: must be an object.")

	var reader := SnapshotReader.new(state)
	var sim := Simulation.from_snapshot(content, reader)
	var problems := reader.errors()
	if not problems.is_empty():
		var more := "" if problems.size() == 1 else " (and %d more problems)" % (problems.size() - 1)
		return LoadResult.failure(LoadResult.Reason.DAMAGED_STATE,
			"The save is damaged: %s%s." % [problems[0], more])
	return LoadResult.success(sim)
