class_name LinkRow
extends PanelContainer
## One link on the screen: its factory and market, vehicle, shipment cost, transit time,
## shipments in transit, and a button to start a shipment.

signal ship_pressed(link_id: int)

const MUTED_COLOR := Color(0.7, 0.72, 0.8)

var link_id: int

var _symbol := ColorSymbol.new()
var _ends_label := Label.new()
var _vehicle_label := Label.new()
var _cost_label := Label.new()
var _transit_label := Label.new()
var _in_transit_label := Label.new()
var _ship_button := Button.new()


func _init(view: LinkView, color: ColorDef, market_name: String, vehicle_name: String) -> void:
	link_id = view.id
	name = "Link%d" % view.id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)

	_symbol.setup(color)
	_symbol.custom_minimum_size = Vector2(32, 32)
	row.add_child(_symbol)

	_ends_label.text = "%s factory #%d to %s" % [color.name, view.source_factory_id, market_name]
	_ends_label.custom_minimum_size.x = 260
	row.add_child(_ends_label)

	_vehicle_label.text = "Vehicle: %s" % vehicle_name
	_vehicle_label.custom_minimum_size.x = 140
	row.add_child(_vehicle_label)

	_cost_label.custom_minimum_size.x = 90
	row.add_child(_cost_label)

	_transit_label.custom_minimum_size.x = 120
	row.add_child(_transit_label)

	_in_transit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Trim instead of widening the row past the screen.
	_in_transit_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_in_transit_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	row.add_child(_in_transit_label)

	_ship_button.name = "Ship"
	_ship_button.text = "Ship"
	_ship_button.custom_minimum_size.x = 90
	_ship_button.pressed.connect(func() -> void: ship_pressed.emit(link_id))
	row.add_child(_ship_button)


func show_state(view: LinkView) -> void:
	_cost_label.text = "Cost: %s" % view.shipment_cost.format()
	_transit_label.text = "Transit: %s" % format_seconds(view.transit_time_ms)
	_in_transit_label.text = _in_transit_text(view.shipments_in_transit)


func ship_button() -> Button:
	return _ship_button


func text() -> String:
	return " | ".join([_ends_label.text, _vehicle_label.text, _cost_label.text,
		_transit_label.text, _in_transit_label.text])


## "5s" or "2.3s". Rounds up, so a shipment never shows "0s" before it arrives.
static func format_seconds(ms: int) -> String:
	var tenths := ceili(ms / 100.0)
	if tenths % 10 == 0:
		@warning_ignore("integer_division")
		return "%ds" % (tenths / 10)
	return "%.1fs" % (tenths / 10.0)


static func _in_transit_text(shipments: Array[ShipmentView]) -> String:
	if shipments.is_empty():
		return "Nothing in transit"
	var widgets := 0
	var next_ms := shipments[0].remaining_ms
	for shipment in shipments:
		widgets += shipment.count
		next_ms = mini(next_ms, shipment.remaining_ms)
	var count_text := BigNumber.from_int(widgets).format()
	if shipments.size() == 1:
		return "%s widgets on the way, arrive in %s" % [count_text, format_seconds(next_ms)]
	return "%s widgets in %d shipments, next in %s" % [
		count_text, shipments.size(), format_seconds(next_ms)]
