extends RefCounted
## Internal to the core. The mutable state of one factory and its production
## rules. Code outside src/core reads factories through FactoryView.

const FactoryState := preload("res://src/core/state/factory_state.gd")

var id: int
var color: StringName
## How many production lines the factory has. Each line makes one widget per
## widget time, which the simulation gives to [method advance].
var size: int = 1
var output_bay_count: int = 0
## Work done on the next widgets, in line-milliseconds: one line working for
## one millisecond adds 1.
var progress_ms: int = 0
## Input color to the widgets in its input bay, in recipe order. Empty for a
## base factory.
var input_bays: Dictionary[StringName, int] = {}
## The time that the factory has made widgets up to. Inside a tick, the
## simulation advances a factory only when an event uses it (see
## [method Simulation._factory_state]). Outside a tick, it is the simulation
## time. It is not in the save, because it is the simulation time there.
var synced_ms: int = 0
## Input color to the count that one widget consumes. Empty for a base factory.
var _recipe: Dictionary[StringName, int]

## More widgets than any output bay holds: the input limit of a base factory.
const _NO_INPUT_LIMIT := 1 << 62


func _init(p_id: int, p_color: StringName, p_recipe: Dictionary[StringName, int]) -> void:
	id = p_id
	color = p_color
	_recipe = p_recipe
	for input in _recipe:
		input_bays[input] = 0


## Makes widgets for [param duration_ms], at one widget per
## [param widget_time_ms] for each line. Constant time for any duration, and
## exact: one long advance gives the same state as many short ones, as long as
## no input arrives and the widget time does not change between them.
## [br][br]
## Each widget consumes one full recipe from the input bays when it is done.
## The factory can make widgets up to the free space in its output bay and up
## to the full recipes in its input bays. At that limit it has stopped (output
## bay full) or waits (an input bay is short), so it keeps no partial progress:
## it starts a new widget when it can make one again. Returns the count of
## widgets made.
func advance(duration_ms: int, balance: FactoryBalance, widget_time_ms: int) -> int:
	var limit := mini(balance.output_bay_capacity - output_bay_count, _recipes_in_bays())
	if limit <= 0:
		progress_ms = 0
		return 0
	# Compare durations, not work, so that a long tick on a large factory
	# cannot overflow.
	var work_to_limit := limit * widget_time_ms - progress_ms
	@warning_ignore("integer_division")
	var time_to_limit := (work_to_limit + size - 1) / size
	var made := limit
	if duration_ms >= time_to_limit:
		progress_ms = 0
	else:
		progress_ms += duration_ms * size
		@warning_ignore("integer_division")
		made = progress_ms / widget_time_ms
		progress_ms -= made * widget_time_ms
	output_bay_count += made
	for input in _recipe:
		input_bays[input] -= made * _recipe[input]
	return made


## How many widgets the input bays hold the inputs for. A base factory needs
## no inputs, so its limit is only its output bay.
func _recipes_in_bays() -> int:
	var full := _NO_INPUT_LIMIT
	for input in _recipe:
		@warning_ignore("integer_division")
		full = mini(full, input_bays[input] / _recipe[input])
	return full


## Puts [param count] widgets of [param input] into its input bay. A shipment
## leaves only with what fits, so the bay never overflows.
func deliver(input: StringName, count: int, balance: FactoryBalance) -> void:
	assert(input_bays.has(input), "factory #%d has no %s input bay" % [id, input])
	assert(input_bays[input] + count <= balance.input_bay_capacity, "input bay overflow")
	input_bays[input] += count


## True if [param input] is a recipe input of this factory.
func uses_input(input: StringName) -> bool:
	return _recipe.has(input)


## The inverse of [method to_dict]. Records problems in [param reader].
static func from_snapshot(reader: SnapshotReader, content: Content) -> FactoryState:
	var color_id := reader.text_id("color")
	var color_def := content.color(color_id)
	if color_id != &"" and color_def == null:
		reader.fail("color", "there is no color \"%s\"" % color_id)
	var recipe: Dictionary[StringName, int] = {}
	if color_def != null:
		recipe = color_def.recipe
	var state := FactoryState.new(reader.integer("id", 1), color_id, recipe)
	state.size = reader.integer("size", 1)
	state.output_bay_count = reader.integer("output_bay_count")
	state.progress_ms = reader.integer("progress_ms")
	var seen := {}
	for bay_reader in reader.objects("input_bays"):
		var input := bay_reader.text_id("color")
		var count := bay_reader.integer("count", 0, content.factory_balance.input_bay_capacity)
		if input == &"":
			continue
		if not recipe.has(input):
			bay_reader.fail("color", "%s is not an input of %s" % [input, color_id])
		elif seen.has(input):
			bay_reader.fail("color", "%s has more than one input bay" % input)
		else:
			state.input_bays[input] = count
		seen[input] = true
	if color_def != null:
		for input in recipe:
			if not seen.has(input):
				reader.fail("input_bays", "there is no input bay for %s" % input)
	return state


## Removes [param count] widgets from the output bay, for a shipment.
func take_output(count: int) -> void:
	assert(count >= 0 and count <= output_bay_count, "cannot take %d of %d widgets" % [count, output_bay_count])
	output_bay_count -= count


func to_view(balance: FactoryBalance) -> FactoryView:
	var view := FactoryView.new()
	view.id = id
	view.color = color
	view.size = size
	view.next_line_cost = balance.next_line_cost(size)
	view.output_bay_count = output_bay_count
	view.output_bay_capacity = balance.output_bay_capacity
	for input in _recipe:
		var bay := InputBayView.new()
		bay.color = input
		bay.count = input_bays[input]
		bay.capacity = balance.input_bay_capacity
		bay.per_widget = _recipe[input]
		view.input_bays.append(bay)
	if output_bay_count >= balance.output_bay_capacity:
		view.status = FactoryView.Status.OUTPUT_BAY_FULL
	elif _recipes_in_bays() <= 0:
		view.status = FactoryView.Status.WAITING_FOR_INPUT
	else:
		view.status = FactoryView.Status.RUNNING
	return view


func to_dict() -> Dictionary:
	var bays: Array[Dictionary] = []
	for input in input_bays:
		bays.append({"color": input, "count": input_bays[input]})
	return {
		"id": id,
		"color": color,
		"size": size,
		"output_bay_count": output_bay_count,
		"progress_ms": progress_ms,
		"input_bays": bays,
	}
