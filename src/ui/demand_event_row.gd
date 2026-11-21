class_name DemandEventRow
extends PanelContainer
## One active demand event on the screen: its name, the symbol and name of
## each of its colors, how much it changes their demand, and the time left.

## The event's id and start time, which tell two events apart.
var key: Array

var _name_label := Label.new()
var _change_label := Label.new()
var _time_label := Label.new()
var _color_names: PackedStringArray = []


func _init(view: DemandEventView, content: Content) -> void:
	key = key_of(view)
	name = "DemandEvent_%s_%d" % [view.id, view.started_at_ms]
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)

	_name_label.text = view.name
	_name_label.custom_minimum_size.x = 200
	row.add_child(_name_label)

	_change_label.text = change_text(view)
	_change_label.add_theme_color_override(&"font_color",
		Color(0.45, 0.85, 0.5) if view.is_spike() else Color(0.95, 0.45, 0.4))
	_change_label.custom_minimum_size.x = 160
	row.add_child(_change_label)

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override(&"h_separation", 16)
	row.add_child(flow)
	for color_id in view.colors:
		var color := content.color(color_id)
		var item := HBoxContainer.new()
		item.name = "Color_%s" % color_id
		item.add_theme_constant_override(&"separation", 8)
		var symbol := ColorSymbol.new().setup(color)
		item.add_child(symbol)
		var label := Label.new()
		label.text = color.name
		item.add_child(label)
		flow.add_child(item)
		_color_names.append(color.name)

	# Room for "Ends in 120s", so the layout does not jump as the time changes.
	_time_label.custom_minimum_size.x = 140
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_time_label)
	show_state(view)


func show_state(view: DemandEventView) -> void:
	_time_label.text = "Ends in %s" % LinkRow.format_seconds(view.remaining_ms)


## The text of the row, for tests: such as
## "Harvest festival: demand up 50%: Orange, Brown. Ends in 90s".
func text() -> String:
	return "%s: %s: %s. %s" % [_name_label.text, _change_label.text.to_lower(),
		", ".join(_color_names), _time_label.text]


## The key of [param view] for [member key].
static func key_of(view: DemandEventView) -> Array:
	return [view.id, view.started_at_ms]


## "Demand up 50%" for a spike of 0.5, "Demand down 40%" for a crash of 0.4.
static func change_text(view: DemandEventView) -> String:
	return "Demand %s %d%%" % ["up" if view.is_spike() else "down", roundi(view.size * 100.0)]
