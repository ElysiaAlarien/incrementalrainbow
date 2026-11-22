class_name DemandEventRow
extends PanelContainer
## One active demand event on the screen: its name, how much it changes the
## demand of its colors, and the time left. Under them, the symbol and name of
## each of its colors, which wrap on a narrow screen.

const SPIKE_COLOR := Color(0.45, 0.85, 0.5)
const CRASH_COLOR := Color(0.95, 0.45, 0.4)

## The event's id and start time, which tell two events apart, such as
## "harvest_festival@90000".
var key: String

var _name_label: Label
var _change_label: Label
var _time_label: Label
var _color_names: PackedStringArray = []


func _init(view: DemandEventView, content: Content) -> void:
	key = key_of(view)
	name = "DemandEvent_%s_%d" % [view.id, view.started_at_ms]
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 6)
	add_child(lines)
	var row := UiTheme.flow()
	lines.add_child(row)

	_name_label = UiTheme.column_label(200)
	_name_label.text = view.name
	row.add_child(_name_label)

	_change_label = UiTheme.column_label(160)
	_change_label.text = change_text(view)
	_change_label.add_theme_color_override(&"font_color",
		SPIKE_COLOR if view.is_spike() else CRASH_COLOR)
	row.add_child(_change_label)

	# Room for "Ends in 120s", so the layout does not jump as the time changes.
	_time_label = UiTheme.column_label(140, true)
	row.add_child(_time_label)

	var flow := UiTheme.flow()
	lines.add_child(flow)
	for color_id in view.colors:
		var color := content.color(color_id)
		var item := HBoxContainer.new()
		item.name = "Color_%s" % color_id
		item.add_theme_constant_override(&"separation", 8)
		var symbol := ColorSymbol.new().setup(color)
		symbol.custom_minimum_size = Vector2(24, 24)
		item.add_child(symbol)
		var label := Label.new()
		label.text = color.name
		item.add_child(label)
		flow.add_child(item)
		_color_names.append(color.name)
	show_state(view)


func show_state(view: DemandEventView) -> void:
	_time_label.text = "Ends in %s" % LinkRow.format_seconds(view.remaining_ms)


## The text of the row, for tests: such as
## "Harvest festival: demand up 50%: Orange, Brown. Ends in 90s".
func text() -> String:
	return "%s: %s: %s. %s" % [_name_label.text, _change_label.text.to_lower(),
		", ".join(_color_names), _time_label.text]


## The key of [param view] for [member key].
static func key_of(view: DemandEventView) -> String:
	return "%s@%d" % [view.id, view.started_at_ms]


## "Demand up 50%" for a spike of 0.5, "Demand down 40%" for a crash of 0.4.
static func change_text(view: DemandEventView) -> String:
	return "Demand %s %d%%" % ["up" if view.is_spike() else "down", roundi(view.size * 100.0)]
