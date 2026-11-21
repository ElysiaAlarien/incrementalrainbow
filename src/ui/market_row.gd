class_name MarketRow
extends PanelContainer
## One market on the screen: its name, and the current price and demand of each
## color there. The colors wrap to more lines when they do not fit.

var market_id: StringName

var _name_label := Label.new()
## Color id to the label that shows its price and demand.
var _color_labels: Dictionary[StringName, Label] = {}


## [param colors] are the colors to show, in order.
func _init(view: MarketView, colors: Array[ColorDef]) -> void:
	market_id = view.id
	name = "Market_%s" % view.id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)

	_name_label.text = view.name
	_name_label.custom_minimum_size.x = 200
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_name_label)

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override(&"h_separation", 24)
	flow.add_theme_constant_override(&"v_separation", 8)
	row.add_child(flow)
	for color in colors:
		var item := HBoxContainer.new()
		item.name = "Color_%s" % color.id
		item.add_theme_constant_override(&"separation", 8)
		var symbol := ColorSymbol.new().setup(color)
		symbol.custom_minimum_size = Vector2(32, 32)
		item.add_child(symbol)
		var label := Label.new()
		# Room for "Price 12.3K, demand 100%", so the layout does not jump as
		# values change.
		label.custom_minimum_size.x = 250
		item.add_child(label)
		flow.add_child(item)
		_color_labels[color.id] = label


func show_state(view: MarketView) -> void:
	for color_id in _color_labels:
		var label := _color_labels[color_id]
		label.text = "Price %s, demand %s" % [view.price(color_id).format(),
			format_demand(view.demand(color_id))]


## The text that shows the price and demand of [param color_id].
func color_text(color_id: StringName) -> String:
	return _color_labels[color_id].text


## Demand as a whole percent of normal demand: "100%", "87%".
static func format_demand(demand: float) -> String:
	return "%d%%" % roundi(demand * 100.0)
