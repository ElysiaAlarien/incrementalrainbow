class_name Simulation
extends RefCounted
## The headless simulation core: all game rules, with no scene-tree dependency.
##
## The rest of the game talks to the core only through this interface
## (see ADR-0008):
## [br]- Commands change state and return a [CommandResult]. A command that is
##   not allowed fails with a reason and does not change state.
## [br]- [method tick] advances time by a duration in integer milliseconds.
## [br]- Queries read state. They return copies, never the live state.
## [br][br]
## The same content, seed, commands, and ticks always give the same state.

const FactoryState := preload("res://src/core/state/factory_state.gd")

var _content: Content
var _rng: SimRng
var _time_ms: int = 0
var _money: BigNumber
var _next_factory_id: int = 1
var _factories: Array[FactoryState] = []


## [param p_content] must be valid (no [member Content.errors]).
func _init(p_content: Content, p_seed: int) -> void:
	assert(p_content.errors.is_empty(), "Simulation needs valid content: %s" % "; ".join(p_content.errors))
	_content = p_content
	_rng = SimRng.new(p_seed)
	_money = _content.starting_money


## Makes a simulation from saved state: the inverse of [method snapshot].
## [param reader] records each problem in the state, and the caller must check
## [method SnapshotReader.errors]. Use [method SaveCodec.decode] to load a save.
static func from_snapshot(p_content: Content, reader: SnapshotReader) -> Simulation:
	var sim := Simulation.new(p_content, 0)
	sim._time_ms = reader.integer("time_ms")
	var rng_state := reader.u32_list("rng", 4)
	if rng_state == PackedInt64Array([0, 0, 0, 0]):
		reader.fail("rng", "cannot be all zeros")
	else:
		sim._rng.set_state(rng_state)
	sim._next_factory_id = reader.integer("next_factory_id", 1)
	var ids := {}
	for factory_reader in reader.objects("factories"):
		var state := FactoryState.from_snapshot(factory_reader, p_content)
		if ids.has(state.id):
			factory_reader.fail("id", "is used by more than one factory")
		elif state.id >= sim._next_factory_id:
			factory_reader.fail("id", "must be less than next_factory_id (%d)" % sim._next_factory_id)
		ids[state.id] = true
		sim._factories.append(state)
	return sim


# --- Commands -----------------------------------------------------------------

## Builds a base factory of [param color]. On success, [member CommandResult.value]
## is the new factory id.
func build_factory(color: StringName) -> CommandResult:
	var color_def := _content.color(color)
	if color_def == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_COLOR,
			"There is no color \"%s\"." % color)
	if not color_def.is_base():
		return CommandResult.failure(CommandResult.Reason.NOT_A_BASE_COLOR,
			"%s needs inputs, so it cannot have a base factory." % color_def.name)

	var state := FactoryState.new(_next_factory_id, color)
	_next_factory_id += 1
	_factories.append(state)
	return CommandResult.success(state.id)


## Adds one production line to the factory with [param factory_id], for money.
## On success, [member CommandResult.value] is the new size of the factory.
func add_production_line(factory_id: int) -> CommandResult:
	var state := _factory_state(factory_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_FACTORY,
			"There is no factory #%d." % factory_id)
	var cost := _content.factory_balance.next_line_cost(state.size)
	if _money.is_less_than(cost):
		return CommandResult.failure(CommandResult.Reason.NOT_ENOUGH_MONEY,
			"A new production line costs %s, but you have only %s." % [cost.format(), _money.format()])

	_money = _money.sub(cost)
	state.size += 1
	return CommandResult.success(state.size)


# --- Time ---------------------------------------------------------------------

## Advances the simulation by [param duration_ms] milliseconds. Time is an
## integer so that one long tick gives the same state as many short ticks.
func tick(duration_ms: int) -> void:
	assert(duration_ms >= 0, "tick duration cannot be negative")
	if duration_ms <= 0:
		return
	for state in _factories:
		state.advance(duration_ms, _content.factory_balance)
	_time_ms += duration_ms


# --- Queries ------------------------------------------------------------------

## Total simulated time.
func time_ms() -> int:
	return _time_ms


## The money the player has now.
func money() -> BigNumber:
	return _money


## The colors that [method build_factory] accepts now, in content order.
func buildable_factory_colors() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in _content.colors():
		if def.is_base():
			ids.append(def.id)
	return ids


## All factories, in build order.
func factories() -> Array[FactoryView]:
	var views: Array[FactoryView] = []
	for state in _factories:
		views.append(state.to_view(_content.factory_balance))
	return views


## The factory with [param id], or null.
func factory(id: int) -> FactoryView:
	var state := _factory_state(id)
	return state.to_view(_content.factory_balance) if state != null else null


## The full state as plain data. Two simulations with equal snapshots behave
## the same from here on. Use it to compare states, not to read single values.
func snapshot() -> Dictionary:
	var factory_dicts: Array[Dictionary] = []
	for state in _factories:
		factory_dicts.append(state.to_dict())
	return {
		"time_ms": _time_ms,
		"rng": _rng.get_state(),
		"money": _money.to_data(),
		"next_factory_id": _next_factory_id,
		"factories": factory_dicts,
	}


# --- Internal -----------------------------------------------------------------

func _factory_state(id: int) -> FactoryState:
	for state in _factories:
		if state.id == id:
			return state
	return null
