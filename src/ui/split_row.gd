class_name SplitRow
extends PanelContainer
## The split of one source on the screen. The first line has the source. Then
## come a percentage box for each automatic link from it, the total of the
## boxes, and buttons to set and to clear the split. The last line has the
## current split: the percentage of each automatic link, or that there is no
## split. The lines wrap on a narrow screen.
## Shipments by hand are outside the split.

signal set_pressed(shares: Dictionary)
signal clear_pressed(link_id: int)

const SPLIT_COLOR := Color(0.6, 0.85, 0.6)
const BAD_TOTAL_COLOR := Color(1.0, 0.55, 0.45)

var _symbol := ColorSymbol.new()
var _source_label := Label.new()
var _boxes_flow: HFlowContainer
var _total_label: Label
var _set_button := Button.new()
var _clear_button := Button.new()
var _state_label: Label
## Link id to the percentage box of that link, in link order.
var _boxes: Dictionary[int, SpinBox] = {}
var _first_link_id: int = 0


## [param key] names the source in the node name, such as "factory_1".
## [param source_name] is such as "Red factory #1".
func _init(key: String, source_name: String, color: ColorDef) -> void:
	name = "Split_%s" % key
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 6)
	add_child(lines)

	_symbol.setup(color)
	_source_label.text = "Split from %s" % source_name
	lines.add_child(UiTheme.title_line(_symbol, _source_label))

	_boxes_flow = UiTheme.flow(24)
	lines.add_child(_boxes_flow)

	var actions := UiTheme.flow(12)
	lines.add_child(actions)
	# Room for "Total: 100%", so the buttons do not move as the total changes.
	_total_label = UiTheme.column_label(130)
	actions.add_child(_total_label)

	_set_button.name = "SetSplit"
	_set_button.text = "Set split"
	_set_button.pressed.connect(func() -> void: set_pressed.emit(shares()))
	actions.add_child(_set_button)

	_clear_button.name = "ClearSplit"
	_clear_button.text = "Clear split"
	_clear_button.pressed.connect(func() -> void: clear_pressed.emit(_first_link_id))
	actions.add_child(_clear_button)

	_state_label = UiTheme.wrapping_label()
	lines.add_child(_state_label)


## Shows the links from the source, in link order. [param names] has the
## destination name of each link, by link id. The boxes are for the automatic
## links. When those change, the boxes are made again and show the current
## split, or equal parts when there is none. Otherwise the boxes keep what the
## player typed.
func show_state(links: Array[LinkView], names: Dictionary[int, String]) -> void:
	_first_link_id = links[0].id
	var automatic := links.filter(func(view: LinkView) -> bool: return view.is_automatic())
	var ids := automatic.map(func(view: LinkView) -> int: return view.id)
	if ids != _boxes.keys():
		_make_boxes(automatic, names)
	var has_split := links[0].split_percent != LinkView.NO_SPLIT
	_clear_button.disabled = not has_split
	if has_split:
		var parts := PackedStringArray()
		for view: LinkView in automatic:
			parts.append("%s %d%%" % [names[view.id], view.split_percent])
		_state_label.text = "Split: %s" % ", ".join(parts)
		_state_label.add_theme_color_override(&"font_color", SPLIT_COLOR)
	else:
		_state_label.text = "No split: each link takes what it can"
		_state_label.add_theme_color_override(&"font_color", UiTheme.MUTED_COLOR)


## The percentage of each automatic link in the boxes, by link id.
func shares() -> Dictionary:
	var result := {}
	for id in _boxes:
		result[id] = int(_boxes[id].value)
	return result


## The percentage box of the link [param link_id], or null.
func percent_box(link_id: int) -> SpinBox:
	return _boxes.get(link_id)


func set_button() -> Button:
	return _set_button


func clear_button() -> Button:
	return _clear_button


func text() -> String:
	return " | ".join([_source_label.text, _total_label.text, _state_label.text])


func _make_boxes(automatic: Array, names: Dictionary[int, String]) -> void:
	for child in _boxes_flow.get_children():
		_boxes_flow.remove_child(child)
		child.queue_free()
	_boxes.clear()
	for i in automatic.size():
		var view: LinkView = automatic[i]
		# The destination name and its box. A long name wraps above the box.
		var item := VBoxContainer.new()
		item.add_theme_constant_override(&"separation", 4)
		var label := Label.new()
		label.text = "to %s" % names[view.id]
		item.add_child(label)
		var stepper := NumberStepper.new(0, 100, "%")
		var box := stepper.spin_box
		box.name = "Percent%d" % view.id
		box.value = view.split_percent if view.split_percent != LinkView.NO_SPLIT \
			else _equal_part(i, automatic.size())
		box.value_changed.connect(func(_value: float) -> void: _show_total())
		item.add_child(stepper)
		_boxes_flow.add_child(item)
		_boxes[view.id] = box
	_set_button.disabled = _boxes.is_empty()
	_show_total()


func _show_total() -> void:
	var total := 0
	for id in _boxes:
		total += int(_boxes[id].value)
	_total_label.text = "Total: %d%%" % total
	_total_label.add_theme_color_override(&"font_color", UiTheme.MUTED_COLOR if total == 100 else BAD_TOTAL_COLOR)


## Part [param index] of 100 split into [param count] whole parts that add up
## to 100, such as 34, 33, and 33.
static func _equal_part(index: int, count: int) -> int:
	@warning_ignore("integer_division")
	return 100 / count + (1 if index < 100 % count else 0)
