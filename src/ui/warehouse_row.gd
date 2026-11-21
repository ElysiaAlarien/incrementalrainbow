class_name WarehouseRow
extends PanelContainer
## One warehouse on the screen: its color and name, the widgets it holds and
## those on their way to it, and its throughput in and out.

const MUTED_COLOR := Color(0.7, 0.72, 0.8)

var warehouse_id: int

var _symbol := ColorSymbol.new()
var _name_label := Label.new()
var _count_label := Label.new()
var _inflow_label := Label.new()
var _outflow_label := Label.new()


func _init(id: int, color: ColorDef) -> void:
	warehouse_id = id
	name = "Warehouse%d" % id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)

	_symbol.setup(color)
	_symbol.custom_minimum_size = Vector2(32, 32)
	row.add_child(_symbol)

	_name_label.text = "%s warehouse #%d" % [color.name, id]
	_name_label.custom_minimum_size.x = 260
	row.add_child(_name_label)

	# Room for "Widgets: 12.3K / 12.3K, 12.3K on the way", so the columns stay
	# in line as values change.
	_count_label.custom_minimum_size.x = 400
	row.add_child(_count_label)

	_inflow_label.custom_minimum_size.x = 160
	_inflow_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	row.add_child(_inflow_label)

	_outflow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outflow_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	row.add_child(_outflow_label)


func show_state(view: WarehouseView) -> void:
	_count_label.text = "Widgets: %s / %s" % [_format(view.count), _format(view.space)]
	if view.in_transit > 0:
		_count_label.text += ", %s on the way" % _format(view.in_transit)
	_inflow_label.text = "In: %s/min" % _format(view.inflow_per_minute)
	_outflow_label.text = "Out: %s/min" % _format(view.outflow_per_minute)


func text() -> String:
	return " | ".join([_name_label.text, _count_label.text, _inflow_label.text, _outflow_label.text])


static func _format(count: int) -> String:
	return BigNumber.from_int(count).format()
