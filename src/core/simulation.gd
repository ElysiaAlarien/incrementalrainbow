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
