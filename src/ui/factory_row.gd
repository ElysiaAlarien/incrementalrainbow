class_name FactoryRow
extends PanelContainer
## One factory on the screen: its color and symbol, its size, its output bay
## count, and whether it has stopped or waits. A mixed factory also shows each
## input bay, and which inputs are short. It has a button to add a production
## line.

## Emits when the player asks to add a production line to this factory.
signal add_line_requested(factory_id: int)

const STOPPED_COLOR := Color(1.0, 0.55, 0.45)
const RUNNING_COLOR := Color(0.6, 0.85, 0.6)
## Text for each status. Add an entry for each new FactoryView.Status.
const STATUS_TEXT: Dictionary[FactoryView.Status, String] = {
	FactoryView.Status.RUNNING: "Running",
	FactoryView.Status.OUTPUT_BAY_FULL: "Stopped: output bay full",
	FactoryView.Status.WAITING_FOR_INPUT: "Waiting for input",
}
const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const INPUT_FONT_SIZE := 16
const BAR_BACKGROUND := Color(0.2, 0.22, 0.29)

var factory_id: int

var _symbol := ColorSymbol.new()
var _name_label := Label.new()
var _size_label := Label.new()
var _add_line_button := Button.new()
var _bay_label := Label.new()
var _bay_bar := ProgressBar.new()
var _status_label := Label.new()
## One label for each input bay, in recipe order.
var _input_labels: Array[Label] = []
## The name of each input color, in recipe order.
var _input_names: PackedStringArray = []


## [param content] gives the input colors of a mixed factory.
func _init(id: int, color: ColorDef, content: Content) -> void:
	factory_id = id
	name = "Factory%d" % id
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 4)
	add_child(lines)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	lines.add_child(row)

	_symbol.setup(color)
	_symbol.custom_minimum_size = Vector2(32, 32)
	row.add_child(_symbol)

	_name_label.text = "%s factory #%d" % [color.name, id]
	_name_label.custom_minimum_size.x = 200
	row.add_child(_name_label)

	_size_label.custom_minimum_size.x = 100
	row.add_child(_size_label)

	_bay_label.custom_minimum_size.x = 200
	row.add_child(_bay_label)

	_bay_bar.custom_minimum_size = Vector2(160, 14)
	_bay_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bay_bar.show_percentage = false
	_bay_bar.add_theme_stylebox_override(&"background", _bar_style(BAR_BACKGROUND))
	_bay_bar.add_theme_stylebox_override(&"fill", _bar_style(color.display_color))
	row.add_child(_bay_bar)

	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status_label)

	_add_line_button.name = "AddLine"
	# Wide enough for most costs, so the columns of each row stay aligned.
	_add_line_button.custom_minimum_size.x = 180
	_add_line_button.pressed.connect(func() -> void: add_line_requested.emit(factory_id))
	row.add_child(_add_line_button)

	if not color.is_base():
		lines.add_child(_input_line(color, content))


## A line under the main row with one entry for each input bay.
func _input_line(color: ColorDef, content: Content) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "InputBays"
	line.add_theme_constant_override(&"separation", 6)
	var title := Label.new()
	title.text = "Input bays:"
	# Starts under the factory name.
	title.custom_minimum_size.x = 32 + 16 + 100
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override(&"font_size", INPUT_FONT_SIZE)
	title.add_theme_color_override(&"font_color", MUTED_COLOR)
	line.add_child(title)
	for input in color.recipe:
		var input_def := content.color(input)
		_input_names.append(input_def.name)
		if not _input_labels.is_empty():
			var gap := Control.new()
			gap.custom_minimum_size.x = 18
			line.add_child(gap)
		var symbol := ColorSymbol.new().setup(input_def)
		symbol.custom_minimum_size = Vector2(18, 18)
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(symbol)
		var label := Label.new()
		# Short counts keep a steady width, so the next bay does not move.
		label.custom_minimum_size.x = 120
		label.add_theme_font_size_override(&"font_size", INPUT_FONT_SIZE)
		line.add_child(label)
		_input_labels.append(label)
	return line


func show_state(view: FactoryView) -> void:
	_size_label.text = "%s %s" % [BigNumber.from_int(view.size).format(),
		"line" if view.size == 1 else "lines"]
	_add_line_button.text = "Add line: %s" % view.next_line_cost.format()
	_bay_label.text = "Output bay: %s / %s" % [
		BigNumber.from_int(view.output_bay_count).format(),
		BigNumber.from_int(view.output_bay_capacity).format()]
	_bay_bar.max_value = view.output_bay_capacity
	_bay_bar.value = view.output_bay_count
	_status_label.text = STATUS_TEXT[view.status]
	_status_label.add_theme_color_override(&"font_color",
		STOPPED_COLOR if view.is_stopped() else RUNNING_COLOR)
	for i in view.input_bays.size():
		_show_input_bay(_input_labels[i], _input_names[i], view.input_bays[i])


## Such as "Blue 3 / 10, 4 on the way". A bay that holds too few widgets for one
## more widget shows "short" in the stopped color.
func _show_input_bay(label: Label, input_name: String, bay: InputBayView) -> void:
	var text := "%s %s / %s" % [input_name, BigNumber.from_int(bay.count).format(),
		BigNumber.from_int(bay.capacity).format()]
	if bay.in_transit > 0:
		text += ", %s on the way" % BigNumber.from_int(bay.in_transit).format()
	if bay.is_short():
		text += " (short)"
	label.text = text
	label.add_theme_color_override(&"font_color", STOPPED_COLOR if bay.is_short() else MUTED_COLOR)


static func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func status_text() -> String:
	return _status_label.text


func input_bay_texts() -> PackedStringArray:
	return PackedStringArray(_input_labels.map(func(label: Label) -> String: return label.text))


func bay_text() -> String:
	return _bay_label.text


func size_text() -> String:
	return _size_label.text


func add_line_button() -> Button:
	return _add_line_button
