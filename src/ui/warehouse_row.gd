class_name WarehouseRow
extends PanelContainer
## One warehouse on the screen. The first line has its color and name. The
## second has the widgets it holds and those on their way to it, and its
## throughput in and out. The third has a box for the sell threshold, and
## buttons to set and to clear it. The last has the current threshold with the
## markets that the warehouse holds its color from now. The lines wrap on a
## narrow screen.

signal set_threshold_pressed(warehouse_id: int, percent: int)
signal clear_threshold_pressed(warehouse_id: int)

const SENDS_COLOR := Color(0.6, 0.85, 0.6)
## The value in the box before the player sets a threshold: normal demand.
const DEFAULT_THRESHOLD := 100
## The highest threshold that the box takes. Demand rarely goes far above 100%.
const MAX_THRESHOLD := 1000

var warehouse_id: int

var _symbol := ColorSymbol.new()
var _name_label := Label.new()
var _count_label: Label
var _inflow_label: Label
var _outflow_label: Label
var _threshold_stepper: NumberStepper
var _threshold_box: SpinBox
var _set_button := Button.new()
var _clear_button := Button.new()
var _threshold_label: Label
## The threshold that the box last took from the simulation, so that the box
## keeps what the player typed until the threshold changes.
var _shown_threshold: int = WarehouseView.NO_SELL_THRESHOLD


func _init(id: int, color: ColorDef) -> void:
	warehouse_id = id
	name = "Warehouse%d" % id
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 6)
	add_child(lines)

	_symbol.setup(color)
	_name_label.text = "%s warehouse #%d" % [color.name, id]
	lines.add_child(UiTheme.title_line(_symbol, _name_label))

	var row := UiTheme.flow()
	lines.add_child(row)
	# Room for "Widgets: 12.3K / 12.3K, 12.3K on the way", so the columns stay
	# in line as values change.
	_count_label = UiTheme.column_label(370)
	row.add_child(_count_label)
	_inflow_label = UiTheme.column_label(140, true)
	row.add_child(_inflow_label)
	_outflow_label = UiTheme.column_label(140, true)
	row.add_child(_outflow_label)

	var threshold := UiTheme.flow(12)
	lines.add_child(threshold)
	var label := Label.new()
	label.text = "Sell threshold"
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	threshold.add_child(label)

	_threshold_stepper = NumberStepper.new(1, MAX_THRESHOLD, "%")
	_threshold_stepper.name = "SellThresholdStepper"
	_threshold_box = _threshold_stepper.spin_box
	_threshold_box.name = "SellThreshold"
	_threshold_box.value = DEFAULT_THRESHOLD
	threshold.add_child(_threshold_stepper)

	_set_button.name = "SetSellThreshold"
	_set_button.text = "Set"
	_set_button.pressed.connect(func() -> void:
		set_threshold_pressed.emit(warehouse_id, int(_threshold_box.value)))
	threshold.add_child(_set_button)

	_clear_button.name = "ClearSellThreshold"
	_clear_button.text = "Clear"
	_clear_button.pressed.connect(func() -> void: clear_threshold_pressed.emit(warehouse_id))
	threshold.add_child(_clear_button)

	_threshold_label = UiTheme.wrapping_label()
	lines.add_child(_threshold_label)


## Shows [param view]. [param held_market_names] has the name of each market in
## [member WarehouseView.held_market_ids], in the same order.
func show_state(view: WarehouseView, held_market_names: PackedStringArray) -> void:
	_count_label.text = "Widgets: %s / %s" % [_format(view.count), _format(view.space)]
	if view.in_transit > 0:
		_count_label.text += ", %s on the way" % _format(view.in_transit)
	_inflow_label.text = "In: %s/min" % _format(view.inflow_per_minute)
	_outflow_label.text = "Out: %s/min" % _format(view.outflow_per_minute)

	if view.sell_threshold != _shown_threshold:
		_shown_threshold = view.sell_threshold
		if view.sell_threshold != WarehouseView.NO_SELL_THRESHOLD:
			_threshold_box.value = view.sell_threshold
	_clear_button.disabled = view.sell_threshold == WarehouseView.NO_SELL_THRESHOLD
	if view.sell_threshold == WarehouseView.NO_SELL_THRESHOLD:
		_threshold_label.text = "None: sends at any demand"
		_threshold_label.add_theme_color_override(&"font_color", UiTheme.MUTED_COLOR)
	elif view.holds():
		_threshold_label.text = "%d%%: holds from %s, where demand is below it" % [
			view.sell_threshold, ", ".join(held_market_names)]
		_threshold_label.add_theme_color_override(&"font_color", LinkRow.HELD_COLOR)
	else:
		_threshold_label.text = "%d%%: sends, demand is at or above it" % view.sell_threshold
		_threshold_label.add_theme_color_override(&"font_color", SENDS_COLOR)


func threshold_box() -> SpinBox:
	return _threshold_box


func set_button() -> Button:
	return _set_button


func clear_button() -> Button:
	return _clear_button


func text() -> String:
	return " | ".join([_name_label.text, _count_label.text, _inflow_label.text, _outflow_label.text,
		_threshold_label.text])


static func _format(count: int) -> String:
	return BigNumber.from_int(count).format()
