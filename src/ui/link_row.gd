class_name LinkRow
extends PanelContainer
## One link on the screen. The first line has its factory and destination (a
## market or a mixed factory), vehicle, shipment cost, transit time, a button
## to start a shipment, and a button to buy automatic transport. The second line has its transport (manual, or what
## automatic transport did last), its throughput, and its shipments in transit.

signal ship_pressed(link_id: int)
signal automate_pressed(link_id: int)

const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const AUTOMATIC_COLOR := Color(0.6, 0.85, 0.6)
const BLOCKED_COLOR := Color(1.0, 0.55, 0.45)

var link_id: int

var _symbol := ColorSymbol.new()
var _ends_label := Label.new()
var _vehicle_label := Label.new()
var _cost_label := Label.new()
var _transit_label := Label.new()
var _ship_button := Button.new()
var _automate_button := Button.new()
var _transport_label := Label.new()
var _throughput_label := Label.new()
var _in_transit_label := Label.new()


func _init(view: LinkView, color: ColorDef, destination_name: String, vehicle_name: String) -> void:
	link_id = view.id
	name = "Link%d" % view.id
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 4)
	add_child(lines)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 16)
	lines.add_child(top)

	_symbol.setup(color)
	_symbol.custom_minimum_size = Vector2(32, 32)
	top.add_child(_symbol)

	_ends_label.text = "%s factory #%d to %s" % [color.name, view.source_factory_id, destination_name]
	_ends_label.tooltip_text = _ends_label.text
	# A fixed width keeps the columns of all rows in line. Trim a long name.
	_ends_label.custom_minimum_size.x = 400
	_ends_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(_ends_label)

	_vehicle_label.text = "Vehicle: %s" % vehicle_name
	_vehicle_label.custom_minimum_size.x = 140
	top.add_child(_vehicle_label)

	_cost_label.custom_minimum_size.x = 90
	top.add_child(_cost_label)

	_transit_label.custom_minimum_size.x = 120
	_transit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_transit_label)

	_ship_button.name = "Ship"
	_ship_button.text = "Ship"
	_ship_button.custom_minimum_size.x = 90
	_ship_button.pressed.connect(func() -> void: ship_pressed.emit(link_id))
	top.add_child(_ship_button)

	_automate_button.name = "Automate"
	_automate_button.custom_minimum_size.x = 190
	_automate_button.pressed.connect(func() -> void: automate_pressed.emit(link_id))
	top.add_child(_automate_button)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 16)
	lines.add_child(bottom)
	# Line up the second line with the text after the symbol.
	var indent := Control.new()
	indent.custom_minimum_size.x = 32
	bottom.add_child(indent)

	_transport_label.custom_minimum_size.x = 520
	bottom.add_child(_transport_label)

	_throughput_label.custom_minimum_size.x = 210
	_throughput_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	bottom.add_child(_throughput_label)

	_in_transit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Trim instead of widening the row past the screen.
	_in_transit_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_in_transit_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	bottom.add_child(_in_transit_label)


## Shows [param view]. [param automatic_cost] is what automatic transport costs now.
func show_state(view: LinkView, automatic_cost: BigNumber) -> void:
	_cost_label.text = "Cost: %s" % view.shipment_cost.format()
	_transit_label.text = "Transit: %s" % format_seconds(view.transit_time_ms)
	# Disable the button instead of hiding it, so the Ship buttons stay in line.
	_automate_button.disabled = view.is_automatic()
	_automate_button.text = "Automatic" if view.is_automatic() else "Automate (%s)" % automatic_cost.format()
	_transport_label.text = transport_text(view)
	_transport_label.add_theme_color_override(&"font_color", _transport_color(view.automatic))
	_throughput_label.text = "Throughput: %s/min" % BigNumber.from_int(view.widgets_per_minute).format()
	_in_transit_label.text = _in_transit_text(view.shipments_in_transit)
	_in_transit_label.tooltip_text = _in_transit_label.text


func ship_button() -> Button:
	return _ship_button


func automate_button() -> Button:
	return _automate_button


func text() -> String:
	return " | ".join([_ends_label.text, _vehicle_label.text, _cost_label.text,
		_transit_label.text, _transport_label.text, _throughput_label.text, _in_transit_label.text])


## "5s" or "2.3s". Rounds up, so a shipment never shows "0s" before it arrives.
static func format_seconds(ms: int) -> String:
	var tenths := ceili(ms / 100.0)
	if tenths % 10 == 0:
		@warning_ignore("integer_division")
		return "%ds" % (tenths / 10)
	return "%.1fs" % (tenths / 10.0)


## What the link's transport does: manual, or what automatic transport did
## last and when it starts the next shipment.
static func transport_text(view: LinkView) -> String:
	var next := format_seconds(view.next_automatic_in_ms)
	match view.automatic:
		LinkView.Automatic.MANUAL:
			return "Manual: you start each shipment"
		LinkView.Automatic.READY:
			return "Automatic: first shipment starts now"
		LinkView.Automatic.SHIPPED:
			return "Automatic: next shipment in %s" % next
		LinkView.Automatic.NOTHING_TO_SHIP:
			return "Automatic: nothing to ship, next try in %s" % next
		LinkView.Automatic.NOT_ENOUGH_MONEY:
			return "Automatic: not enough money, next try in %s" % next
	return ""


static func _transport_color(automatic: LinkView.Automatic) -> Color:
	match automatic:
		LinkView.Automatic.MANUAL:
			return MUTED_COLOR
		LinkView.Automatic.NOT_ENOUGH_MONEY:
			return BLOCKED_COLOR
	return AUTOMATIC_COLOR


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
