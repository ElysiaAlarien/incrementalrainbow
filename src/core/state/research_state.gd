extends RefCounted
## Internal to the core. All research state of a run, in one place, so that
## prestige can clear it: the selected research, the widgets paid toward each
## research that is not complete, the research that is complete, and the lab
## stock. Code outside src/core reads research through ResearchView.
##
## Labs consume the widgets that arrive to pay for the selected research. A
## widget that the selected research does not need when it arrives (because
## the player selected other research while it was on its way) goes into the
## lab stock. Stock pays for the selected research first, when the player
## selects research and when widgets arrive, so that no widget is lost.

const ResearchState := preload("res://src/core/state/research_state.gd")

## The research that labs pay for now, or &"" when there is none.
var selected: StringName = &""
## Research id to color id to the widgets paid. Only research that is not
## complete and has had a payment is here. Each has every color of its cost.
var _paid: Dictionary[StringName, Dictionary] = {}
## Complete research ids, in the order of completion.
var _completed: Array[StringName] = []
## Color id to the widgets in the lab stock. Only colors with widgets are here.
var _stock: Dictionary[StringName, int] = {}


func is_complete(id: StringName) -> bool:
	return _completed.has(id)


## The complete research ids, in the order of completion.
func completed() -> Array[StringName]:
	return _completed.duplicate()


## True if complete research unlocks [param color].
func unlocks_color(color: StringName, content: Content) -> bool:
	for id in _completed:
		if content.research_def(id).unlocks_color(color):
			return true
	return false


## True if each research that [param def] requires is complete.
func has_requirements(def: ResearchDef) -> bool:
	for id in def.requires:
		if not is_complete(id):
			return false
	return true


## Widgets of [param color] paid toward [param id], which is not complete.
func paid(id: StringName, color: StringName) -> int:
	var colors: Dictionary = _paid.get(id, {})
	return colors.get(color, 0)


## Widgets of [param color] in the lab stock.
func stock(color: StringName) -> int:
	return _stock.get(color, 0)


## The lab stock, as color id to widgets, in content order.
func stock_counts(content: Content) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for def in content.colors():
		if _stock.has(def.id):
			counts[def.id] = _stock[def.id]
	return counts


## Widgets of [param color] that the selected research still needs. 0 when
## nothing is selected.
func needs(color: StringName, content: Content) -> int:
	if selected == &"":
		return 0
	return content.research_def(selected).cost.get(color, 0) - paid(selected, color)


## A view of [param def] with its status and progress. [param in_transit]
## is color id to the widgets on their way to labs; they count for the
## selected research only.
func to_view(def: ResearchDef, in_transit: Dictionary[StringName, int]) -> ResearchView:
	var view := ResearchView.new()
	view.id = def.id
	view.name = def.name
	view.cost = def.cost
	view.requires = def.requires
	view.unlock_colors = def.unlock_colors
	var complete := is_complete(def.id)
	for color in view.cost:
		view.paid[color] = view.cost[color] if complete else paid(def.id, color)
		view.in_transit[color] = in_transit.get(color, 0) if selected == def.id else 0
	if complete:
		view.status = ResearchView.Status.COMPLETE
	elif selected == def.id:
		view.status = ResearchView.Status.SELECTED
	elif has_requirements(def):
		view.status = ResearchView.Status.AVAILABLE
	else:
		view.status = ResearchView.Status.LOCKED
	return view


## Selects [param id]. The simulation checks that it is known, not complete,
## and has its requirements. The stock pays for it at once, which can complete
## it.
func select(id: StringName, content: Content) -> void:
	selected = id
	_pay_from_stock(content)


## Puts [param count] widgets of [param color] that arrived at a lab into the
## stock, which pays for the selected research.
func deliver(color: StringName, count: int, content: Content) -> void:
	_stock[color] = stock(color) + count
	_pay_from_stock(content)


## Pays for the selected research from the stock, as much as it needs. When it
## has all of its cost, it is complete, and nothing is selected.
func _pay_from_stock(content: Content) -> void:
	if selected == &"":
		return
	var cost := content.research_def(selected).cost
	var done := true
	for color in cost:
		var take := mini(stock(color), cost[color] - paid(selected, color))
		if take > 0:
			if not _paid.has(selected):
				_paid[selected] = {}
				for cost_color in cost:
					_paid[selected][cost_color] = 0
			_paid[selected][color] += take
			_stock[color] -= take
			if _stock[color] == 0:
				_stock.erase(color)
		if paid(selected, color) < cost[color]:
			done = false
	if done:
		_paid.erase(selected)
		_completed.append(selected)
		selected = &""


## The state as plain data for [method Simulation.snapshot]: the keys
## "selected_research", "research_progress", "completed_research", and
## "lab_stock". Progress and stock are in content order, so that equal
## states give equal snapshots.
func to_dict(content: Content) -> Dictionary:
	var progress: Array[Dictionary] = []
	for def in content.research():
		if not _paid.has(def.id):
			continue
		var paid_list: Array[Dictionary] = []
		for color: StringName in _paid[def.id]:
			paid_list.append({"color": String(color), "count": _paid[def.id][color]})
		progress.append({"research": String(def.id), "paid": paid_list})
	var stock_list: Array[Dictionary] = []
	var counts := stock_counts(content)
	for color in counts:
		stock_list.append({"color": String(color), "count": counts[color]})
	return {
		"selected_research": String(selected),
		"research_progress": progress,
		"completed_research": _completed.map(func(id: StringName) -> String: return String(id)),
		"lab_stock": stock_list,
	}


## The inverse of [method to_dict]. [param reader] reads the snapshot root.
## Records problems in it.
static func from_snapshot(reader: SnapshotReader, content: Content) -> ResearchState:
	var state := ResearchState.new()
	state._read_completed(reader, content)
	state._read_progress(reader, content)
	state._read_stock(reader, content)
	var id := reader.optional_text_id("selected_research")
	if id == &"":
		return state
	var def := content.research_def(id)
	if def == null:
		reader.fail("selected_research", "there is no research \"%s\"" % id)
	elif state.is_complete(id):
		reader.fail("selected_research", "%s is complete" % id)
	elif not state.has_requirements(def):
		reader.fail("selected_research", "%s requires research that is not complete" % id)
	else:
		state.selected = id
		for color in def.cost:
			if state.stock(color) > 0 and state.needs(color, content) > 0:
				reader.fail("lab_stock", "%s is in the stock, but %s still needs it" % [color, id])
	return state


func _read_completed(reader: SnapshotReader, content: Content) -> void:
	for id in reader.text_id_list("completed_research"):
		var def := content.research_def(id)
		if def == null:
			reader.fail("completed_research", "there is no research \"%s\"" % id)
		elif is_complete(id):
			reader.fail("completed_research", "%s is in the list more than once" % id)
		elif not has_requirements(def):
			reader.fail("completed_research", "%s comes before research that it requires" % id)
		else:
			_completed.append(id)


func _read_progress(reader: SnapshotReader, content: Content) -> void:
	for entry in reader.objects("research_progress"):
		var id := entry.text_id("research")
		var def := content.research_def(id)
		if id != &"" and def == null:
			entry.fail("research", "there is no research \"%s\"" % id)
		elif is_complete(id):
			entry.fail("research", "%s is complete, so it has no progress" % id)
		elif _paid.has(id):
			entry.fail("research", "%s has more than one progress entry" % id)
		var cost: Dictionary[StringName, int] = {}
		if def != null:
			cost = def.cost
		var colors: Dictionary[StringName, int] = {}
		var total := 0
		for paid_reader in entry.objects("paid"):
			var color := paid_reader.text_id("color")
			var count := paid_reader.integer("count", 0, cost.get(color, 0))
			if color == &"":
				continue
			if not cost.has(color):
				paid_reader.fail("color", "%s is not in the cost of %s" % [color, id])
			elif colors.has(color):
				paid_reader.fail("color", "%s is in the list more than once" % color)
			else:
				colors[color] = count
				total += count
		if def == null or is_complete(id) or _paid.has(id):
			continue
		var full := true
		for color in cost:
			if not colors.has(color):
				entry.fail("paid", "there is no entry for %s" % color)
			elif colors[color] < cost[color]:
				full = false
		if total == 0:
			entry.fail("paid", "%s has no widgets paid, so it has no progress" % id)
		elif full:
			entry.fail("paid", "%s has its full cost, so it must be complete" % id)
		_paid[id] = {}
		for color in cost:
			_paid[id][color] = colors.get(color, 0)


func _read_stock(reader: SnapshotReader, content: Content) -> void:
	for entry in reader.objects("lab_stock"):
		var color := entry.text_id("color")
		var count := entry.integer("count", 1)
		if color == &"":
			continue
		if content.color(color) == null:
			entry.fail("color", "there is no color \"%s\"" % color)
		elif _stock.has(color):
			entry.fail("color", "%s is in the stock more than once" % color)
		else:
			_stock[color] = count
