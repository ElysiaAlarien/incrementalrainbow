class_name FactoryRow
extends PanelContainer
## One factory on the screen: its color and symbol, its output bay count, and
## whether it has stopped.

const STOPPED_COLOR := Color(1.0, 0.55, 0.45)
const RUNNING_COLOR := Color(0.6, 0.85, 0.6)
const BAR_BACKGROUND := Color(0.2, 0.22, 0.29)

var factory_id: int

var _symbol := ColorSymbol.new()
var _name_label := Label.new()
var _bay_label := Label.new()
var _bay_bar := ProgressBar.new()
var _status_label := Label.new()


func _init(id: int, color: ColorDef) -> void:
	factory_id = id
	name = "Factory%d" % id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)

	_symbol.setup(color)
	_symbol.custom_minimum_size = Vector2(32, 32)
	row.add_child(_symbol)

	_name_label.text = "%s factory #%d" % [color.name, id]
	_name_label.custom_minimum_size.x = 220
	row.add_child(_name_label)

	_bay_label.custom_minimum_size.x = 230
	row.add_child(_bay_label)

	_bay_bar.custom_minimum_size = Vector2(160, 14)
	_bay_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bay_bar.show_percentage = false
	_bay_bar.add_theme_stylebox_override(&"background", _bar_style(BAR_BACKGROUND))
	_bay_bar.add_theme_stylebox_override(&"fill", _bar_style(color.display_color))
	row.add_child(_bay_bar)

	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status_label)


func show_state(view: FactoryView) -> void:
	_bay_label.text = "Output bay: %s / %s" % [
		BigNumber.from_int(view.output_bay_count).format(),
		BigNumber.from_int(view.output_bay_capacity).format()]
	_bay_bar.max_value = view.output_bay_capacity
	_bay_bar.value = view.output_bay_count
	match view.status:
		FactoryView.Status.OUTPUT_BAY_FULL:
			_status_label.text = "Stopped: output bay full"
			_status_label.add_theme_color_override(&"font_color", STOPPED_COLOR)
		_:
			_status_label.text = "Running"
			_status_label.add_theme_color_override(&"font_color", RUNNING_COLOR)


static func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func status_text() -> String:
	return _status_label.text


func bay_text() -> String:
	return _bay_label.text
