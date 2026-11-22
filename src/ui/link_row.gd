class_name LinkRow
extends PanelContainer
## One link on the screen. The first line has its source (a factory or a
## warehouse) and destination (a market, a mixed factory, a warehouse, or a
## lab). The second has its vehicle, shipment cost, transit time, a button to
## start a shipment, and a button to buy automatic transport. The third has
## its transport (manual, or what automatic transport did last), its
## throughput, and its shipments in transit. A last line shows only when the
## player's transport tier is above the link's vehicle: what the newer vehicle
## does, and a button to upgrade to it. The lines wrap on a narrow screen.

signal ship_pressed(link_id: int)
signal automate_pressed(link_id: int)
signal upgrade_vehicle_pressed(link_id: int)

const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const AUTOMATIC_COLOR := Color(0.6, 0.85, 0.6)
const BLOCKED_COLOR := Color(1.0, 0.55, 0.45)
const UPGRADE_COLOR := Color(0.98, 0.85, 0.45)
## For a link that its warehouse holds, here and in [WarehouseRow].
const HELD_COLOR := Color(0.98, 0.85, 0.45)

var link_id: int

var _symbol := ColorSymbol.new()
var _ends_label := Label.new()
var _vehicle_label: Label
var _cost_label: Label
var _transit_label: Label
var _ship_button := Button.new()
var _automate_button := Button.new()
var _transport_label: Label
var _throughput_label: Label
var _in_transit_label: Label
var _upgrade_line: HFlowContainer
var _upgrade_label: Label
var _upgrade_button := Button.new()


func _init(view: LinkView, color: ColorDef, source_name: String, destination_name: String) -> void:
	link_id = view.id
	name = "Link%d" % view.id
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 6)
	add_child(lines)

	_symbol.setup(color)
	_ends_label.text = "%s to %s" % [source_name, destination_name]
	lines.add_child(UiTheme.title_line(_symbol, _ends_label))

	var top := UiTheme.flow()
	lines.add_child(top)
	_vehicle_label = UiTheme.column_label(140)
	top.add_child(_vehicle_label)
	_cost_label = UiTheme.column_label(100)
	top.add_child(_cost_label)
	_transit_label = UiTheme.column_label(120)
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

	var bottom := UiTheme.flow()
	lines.add_child(bottom)
	# Room for the longest transport text, so the columns stay in line.
	_transport_label = UiTheme.column_label(430, true)
	bottom.add_child(_transport_label)
	_throughput_label = UiTheme.column_label(170, true)
	bottom.add_child(_throughput_label)
	_in_transit_label = UiTheme.column_label(0, true)
	bottom.add_child(_in_transit_label)

	_upgrade_line = UiTheme.flow()
	_upgrade_line.visible = false
	lines.add_child(_upgrade_line)
	_upgrade_label = UiTheme.column_label(0)
	_upgrade_label.add_theme_color_override(&"font_color", UPGRADE_COLOR)
	_upgrade_line.add_child(_upgrade_label)
	_upgrade_button.name = "UpgradeVehicle"
	_upgrade_button.custom_minimum_size.x = 190
	_upgrade_button.pressed.connect(func() -> void: upgrade_vehicle_pressed.emit(link_id))
	_upgrade_line.add_child(_upgrade_button)


## Shows [param view]. [param automatic_cost] is what automatic transport costs
## now. [param vehicle] is the tier of the link's vehicle, and [param tier] is
## the player's transport tier, which an upgrade moves the vehicle onto.
func show_state(view: LinkView, automatic_cost: BigNumber, vehicle: TransportTier,
		tier: TransportTier) -> void:
	_vehicle_label.text = "Vehicle: %s" % vehicle.name
	_upgrade_line.visible = vehicle != tier
	if vehicle != tier:
		_upgrade_label.text = "%s are ready for this link: transit %s, cost %s" % [tier.plural_name,
			format_seconds(tier.transit_time_ms), tier.shipment_cost.format()]
		_upgrade_button.text = "Upgrade (%s)" % tier.vehicle_upgrade_cost.format()
	_cost_label.text = "Cost: %s" % view.shipment_cost.format()
	_transit_label.text = "Transit: %s" % format_seconds(view.transit_time_ms)
	# Disable the button instead of hiding it, so the Ship buttons stay in line.
	_automate_button.disabled = view.is_automatic()
	_automate_button.text = "Automatic" if view.is_automatic() else "Automate (%s)" % automatic_cost.format()
	_transport_label.text = transport_text(view)
	_transport_label.add_theme_color_override(&"font_color", _transport_color(view.automatic))
	_throughput_label.text = "Throughput: %s/min" % BigNumber.from_int(view.widgets_per_minute).format()
	_in_transit_label.text = _in_transit_text(view.shipments_in_transit)


func ship_button() -> Button:
	return _ship_button


func automate_button() -> Button:
	return _automate_button


func upgrade_button() -> Button:
	return _upgrade_button


## The text of the line that offers a vehicle upgrade, or "" when it is hidden.
func upgrade_text() -> String:
	return _upgrade_label.text if _upgrade_line.visible else ""


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
		LinkView.Automatic.HELD:
			return "Automatic: held by the sell threshold, next try in %s" % next
	return ""


static func _transport_color(automatic: LinkView.Automatic) -> Color:
	match automatic:
		LinkView.Automatic.MANUAL:
			return MUTED_COLOR
		LinkView.Automatic.NOT_ENOUGH_MONEY:
			return BLOCKED_COLOR
		LinkView.Automatic.HELD:
			return HELD_COLOR
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
		if widgets == 1:
			return "1 widget on the way, arrives in %s" % format_seconds(next_ms)
		return "%s widgets on the way, arrive in %s" % [count_text, format_seconds(next_ms)]
	return "%s widgets in %d shipments, next in %s" % [
		count_text, shipments.size(), format_seconds(next_ms)]
