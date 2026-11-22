class_name ResearchRow
extends PanelContainer
## One research on the screen. The first line has its name, its status, and a
## button to select it. The second line has its cost in widgets of each color,
## with what labs have paid and what is on the way. The third line has what it
## unlocks, and the research that it requires.

signal select_pressed(research_id: StringName)

const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const SELECTED_COLOR := Color(0.6, 0.85, 0.6)
const LOCKED_COLOR := Color(1.0, 0.55, 0.45)

var research_id: StringName

var _content: Content
var _name_label := Label.new()
var _status_label := Label.new()
var _select_button := Button.new()
## Color id to the label that shows the paid widgets of that color.
var _cost_labels: Dictionary[StringName, Label] = {}
var _unlocks_label := Label.new()


func _init(view: ResearchView, content: Content) -> void:
	research_id = view.id
	_content = content
	name = "Research_%s" % view.id
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 4)
	add_child(lines)

	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 16)
	lines.add_child(top)
	_name_label.text = view.name
	_name_label.custom_minimum_size.x = 260
	top.add_child(_name_label)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status_label)
	_select_button.name = "Select"
	_select_button.text = "Select"
	_select_button.custom_minimum_size.x = 120
	_select_button.pressed.connect(func() -> void: select_pressed.emit(research_id))
	top.add_child(_select_button)

	var cost_line := HFlowContainer.new()
	cost_line.add_theme_constant_override(&"h_separation", 24)
	lines.add_child(cost_line)
	for color_id in view.cost:
		var item := HBoxContainer.new()
		item.add_theme_constant_override(&"separation", 8)
		var symbol := ColorSymbol.new().setup(content.color(color_id))
		symbol.custom_minimum_size = Vector2(24, 24)
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(symbol)
		var label := Label.new()
		item.add_child(label)
		cost_line.add_child(item)
		_cost_labels[color_id] = label

	_unlocks_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	_unlocks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_unlocks_label)


## Shows the status and progress in [param view].
func show_state(view: ResearchView) -> void:
	_status_label.text = status_text(view.status)
	_status_label.add_theme_color_override(&"font_color", _status_color(view.status))
	# Disable the button instead of hiding it, so the rows stay in line.
	_select_button.disabled = view.status != ResearchView.Status.AVAILABLE
	_select_button.text = "Selected" if view.status == ResearchView.Status.SELECTED else "Select"
	for color_id in _cost_labels:
		_cost_labels[color_id].text = cost_text(_content.color(color_id).name, view.paid[color_id],
			view.cost[color_id], view.in_transit[color_id])
	var parts := PackedStringArray()
	parts.append("Unlocks: %s" % unlocks_text(_color_names(view.unlock_colors), view.forecast_accuracy))
	if view.status == ResearchView.Status.LOCKED:
		parts.append("Needs research first: %s" % ", ".join(_content.research_names(view.requires)))
	_unlocks_label.text = ". ".join(parts)


## The button that selects the research. For smoke tests.
func select_button() -> Button:
	return _select_button


## All text of the row, for smoke tests.
func text() -> String:
	var parts := PackedStringArray([_name_label.text, _status_label.text])
	for color_id in _cost_labels:
		parts.append(_cost_labels[color_id].text)
	parts.append(_unlocks_label.text)
	return " | ".join(parts)


## Such as "Red 3 / 10 (+2 on the way)".
static func cost_text(color_name: String, paid: int, cost: int, in_transit: int) -> String:
	var text := "%s %s / %s" % [color_name, BigNumber.from_int(paid).format(),
		BigNumber.from_int(cost).format()]
	if in_transit > 0:
		text += " (+%s on the way)" % BigNumber.from_int(in_transit).format()
	return text


## Such as "Brown", "Forecast accuracy +30%", or both, with a comma.
## [param color_names] is the names of the colors that it unlocks, such as
## "Red-orange, Yellow-orange", or "".
static func unlocks_text(color_names: String, forecast_accuracy: float) -> String:
	var parts := PackedStringArray()
	if not color_names.is_empty():
		parts.append(color_names)
	if forecast_accuracy > 0.0:
		parts.append("Forecast accuracy +%s" % MarketRow.format_demand(forecast_accuracy))
	return ", ".join(parts)


## Such as "Complete".
static func status_text(status: ResearchView.Status) -> String:
	match status:
		ResearchView.Status.LOCKED:
			return "Locked"
		ResearchView.Status.AVAILABLE:
			return "Not selected"
		ResearchView.Status.SELECTED:
			return "Selected: labs pay for it"
		ResearchView.Status.COMPLETE:
			return "Complete"
	return ""


static func _status_color(status: ResearchView.Status) -> Color:
	match status:
		ResearchView.Status.SELECTED, ResearchView.Status.COMPLETE:
			return SELECTED_COLOR
		ResearchView.Status.LOCKED:
			return LOCKED_COLOR
	return MUTED_COLOR


func _color_names(ids: Array[StringName]) -> String:
	var names := PackedStringArray()
	for id in ids:
		names.append(_content.color(id).name)
	return ", ".join(names)
