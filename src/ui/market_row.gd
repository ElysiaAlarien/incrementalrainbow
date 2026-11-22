class_name MarketRow
extends PanelContainer
## One market on the screen. On the left: its name, its remoteness with the
## transport tier it needs, and a button for each kind of community
## investment, with its cost. On the right, the first line has its population,
## income, the capacity used in this period, and the time until the next
## period. Below it, the current price, demand, and forecast of each color
## there. The colors wrap to more lines when they do not fit.

signal invest_pressed(market_id: StringName, goal: MarketView.Investment)

const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const BLOCKED_COLOR := Color(1.0, 0.55, 0.45)

var market_id: StringName

var _name_label := Label.new()
var _population_label := Label.new()
var _income_label := Label.new()
var _capacity_label := Label.new()
var _period_label := Label.new()
## Investment goal to its button.
var _invest_buttons: Dictionary[MarketView.Investment, Button] = {}
var _reach_label := Label.new()
## Color id to the label that shows its price, demand, and forecast.
var _color_labels: Dictionary[StringName, Label] = {}


## [param colors] are the colors to show, in order.
func _init(view: MarketView, colors: Array[ColorDef]) -> void:
	market_id = view.id
	name = "Market_%s" % view.id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	left.add_theme_constant_override(&"separation", 4)
	row.add_child(left)
	_name_label.text = view.name
	left.add_child(_name_label)
	_reach_label.add_theme_font_size_override(&"font_size", 16)
	left.add_child(_reach_label)
	for goal: MarketView.Investment in [MarketView.Investment.POPULATION, MarketView.Investment.INCOME]:
		var button := Button.new()
		button.name = "InvestPopulation" if goal == MarketView.Investment.POPULATION else "InvestIncome"
		button.tooltip_text = "A community investment for %s" % (
			"population, which gives more capacity" if goal == MarketView.Investment.POPULATION
			else "income, which gives higher prices")
		button.pressed.connect(func() -> void: invest_pressed.emit(market_id, goal))
		left.add_child(button)
		_invest_buttons[goal] = button

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	row.add_child(right)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 24)
	right.add_child(stats)
	# Fixed widths keep the layout still as values change.
	_population_label.custom_minimum_size.x = 170
	stats.add_child(_population_label)
	_income_label.custom_minimum_size.x = 120
	stats.add_child(_income_label)
	_capacity_label.custom_minimum_size.x = 380
	stats.add_child(_capacity_label)
	_period_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	stats.add_child(_period_label)

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override(&"h_separation", 24)
	flow.add_theme_constant_override(&"v_separation", 8)
	right.add_child(flow)
	for color in colors:
		var item := HBoxContainer.new()
		item.name = "Color_%s" % color.id
		item.add_theme_constant_override(&"separation", 8)
		var symbol := ColorSymbol.new().setup(color)
		symbol.custom_minimum_size = Vector2(32, 32)
		item.add_child(symbol)
		var label := Label.new()
		# Room for "Price 31.47, demand 112%, forecast 110%", so the layout
		# does not jump as values change.
		label.custom_minimum_size.x = 410
		item.add_child(label)
		flow.add_child(item)
		_color_labels[color.id] = label


## Shows [param view] and the demand in [param forecast]. [param needed_tier_plural]
## is the plural name of the transport tier that the market needs, such as
## "Trucks", or "" when no tier reaches it.
func show_state(view: MarketView, needed_tier_plural: String, forecast: ForecastView) -> void:
	_reach_label.text = reach_text(view, needed_tier_plural)
	_reach_label.add_theme_color_override(&"font_color", MUTED_COLOR if view.is_open else BLOCKED_COLOR)
	_population_label.text = "Population: %s" % BigNumber.from_int(view.population).format()
	_income_label.text = "Income: %s" % BigNumber.from_int(view.income).format()
	_capacity_label.text = capacity_text(view)
	if view.capacity_left == 0:
		_capacity_label.add_theme_color_override(&"font_color", BLOCKED_COLOR)
	else:
		_capacity_label.remove_theme_color_override(&"font_color")
	_period_label.text = "New period in %s" % LinkRow.format_seconds(view.period_ends_in_ms)
	for goal in _invest_buttons:
		_invest_buttons[goal].text = "%s (%s)" % [
			"Grow population" if goal == MarketView.Investment.POPULATION else "Grow income",
			view.investment_cost(goal).format()]
	for color_id in _color_labels:
		var label := _color_labels[color_id]
		label.text = "Price %s, demand %s, forecast %s" % [view.price(color_id).format(),
			format_demand(view.demand(color_id)), format_demand(forecast.demand(market_id, color_id))]


## Such as "Remoteness 2, open to trucks" or "Remoteness 4, needs trains".
static func reach_text(view: MarketView, needed_tier_plural: String) -> String:
	if needed_tier_plural.is_empty():
		return "Remoteness %d, no transport tier reaches it yet" % view.remoteness
	return "Remoteness %d, %s %s" % [view.remoteness, "open to" if view.is_open else "needs",
		needed_tier_plural.to_lower()]


## The text that shows the remoteness and the tier the market needs.
func reach_label_text() -> String:
	return _reach_label.text


## The text that shows the price, demand, and forecast of [param color_id].
func color_text(color_id: StringName) -> String:
	return _color_labels[color_id].text


## The text that shows the population, income, capacity, and period.
func stats_text() -> String:
	return " | ".join([_population_label.text, _income_label.text, _capacity_label.text, _period_label.text])


func invest_button(goal: MarketView.Investment) -> Button:
	return _invest_buttons[goal]


## Such as "Capacity: 40 of 100 used, 6 on the way" or "Capacity: 100 of 100
## used, none left".
static func capacity_text(view: MarketView) -> String:
	var text := "Capacity: %s of %s used" % [BigNumber.from_int(view.capacity_used).format(),
		BigNumber.from_int(view.capacity).format()]
	if view.capacity_in_transit > 0:
		text += ", %s on the way" % BigNumber.from_int(view.capacity_in_transit).format()
	if view.capacity_left == 0:
		text += ", none left"
	return text


## Such as "Forecast: the demand in 60s, 10% accurate. Forecast research
## makes it more accurate."
static func forecast_text(forecast: ForecastView) -> String:
	var text := "Forecast: the demand in %s, %s accurate." % [LinkRow.format_seconds(forecast.ahead_ms),
		format_demand(forecast.accuracy)]
	if forecast.accuracy < 1.0:
		text += " Forecast research makes it more accurate."
	return text


## Demand as a whole percent of normal demand, or an accuracy as a whole
## percent: "100%", "87%".
static func format_demand(demand: float) -> String:
	return "%d%%" % MarketView.demand_percent(demand)
