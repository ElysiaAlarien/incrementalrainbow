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
var _next_factory_id: int = 1
var _factories: Array[FactoryState] = []


## [param content] must be valid (no [member Content.errors]).
func _init(content: Content, seed: int) -> void:
	assert(content.errors.is_empty(), "Simulation needs valid content: %s" % "; ".join(content.errors))
	_content = content
	_rng = SimRng.new(seed)


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

	var factory := FactoryState.new(_next_factory_id, color)
	_next_factory_id += 1
	_factories.append(factory)
	return CommandResult.success(factory.id)


# --- Time ---------------------------------------------------------------------

## Advances the simulation by [param duration_ms] milliseconds. Time is an
## integer so that one long tick gives the same state as many short ticks.
func tick(duration_ms: int) -> void:
	assert(duration_ms >= 0, "tick duration cannot be negative")
	if duration_ms <= 0:
		return
	for factory in _factories:
		factory.advance(duration_ms, _content.widget_time_ms, _content.output_bay_capacity)
	_time_ms += duration_ms


# --- Queries ------------------------------------------------------------------

## The content this simulation runs on. Treat it as read-only.
func content() -> Content:
	return _content


## Total simulated time.
func time_ms() -> int:
	return _time_ms


## The colors that [method build_factory] accepts now, in content order.
func buildable_factory_colors() -> Array[StringName]:
	var ids: Array[StringName] = []
	for color in _content.colors():
		if color.is_base():
			ids.append(color.id)
	return ids


## All factories, in build order.
func factories() -> Array[FactoryView]:
	var views: Array[FactoryView] = []
	for factory in _factories:
		views.append(_view_of(factory))
	return views


## The factory with [param id], or null.
func factory(id: int) -> FactoryView:
	for f in _factories:
		if f.id == id:
			return _view_of(f)
	return null


## The full state as plain data. Two simulations with equal snapshots behave
## the same from here on. Use it to compare states, not to read single values.
func snapshot() -> Dictionary:
	var factory_dicts: Array[Dictionary] = []
	for f in _factories:
		factory_dicts.append(f.to_dict())
	return {
		"time_ms": _time_ms,
		"rng": _rng.get_state(),
		"next_factory_id": _next_factory_id,
		"factories": factory_dicts,
	}


func _view_of(f: FactoryState) -> FactoryView:
	var view := FactoryView.new()
	view.id = f.id
	view.color = f.color
	view.output_bay_count = f.output_bay_count
	view.output_bay_capacity = _content.output_bay_capacity
	view.status = FactoryView.Status.OUTPUT_BAY_FULL \
		if f.is_output_bay_full(_content.output_bay_capacity) else FactoryView.Status.RUNNING
	return view
