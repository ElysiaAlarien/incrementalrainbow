class_name MarketRow
extends PanelContainer
## One market on the screen. At the top: its name, and its remoteness with the
## transport tier it needs. Then its population, income, and the time until
## the next period, the capacity used in this period, and a button for each
## kind of community investment, with its cost. Then a grid with the current
## price, demand, and forecast of each color there. The grid has as many
## columns as fit the screen.

signal invest_pressed(market_id: StringName, goal: MarketView.Investment)

const BLOCKED_COLOR := Color(1.0, 0.55, 0.45)
## The narrowest that a column of the price grid can be.
const PRICE_COLUMN_WIDTH := 360.0

var market_id: StringName

var _name_label := Label.new()
var _population_label: Label
var _income_label: Label
var _capacity_label: Label
var _period_label: Label
## Investment goal to its button.
var _invest_buttons: Dictionary[MarketView.Investment, Button] = {}
var _reach_label: Label
## Color id to the labels that show its price, its demand, and its forecast.
var _price_labels: Dictionary[StringName, Label] = {}
var _demand_labels: Dictionary[StringName, Label] = {}
var _forecast_labels: Dictionary[StringName, Label] = {}


## [param colors] are the colors to show, in order.
func _init(view: MarketView, colors: Array[ColorDef]) -> void:
	market_id = view.id
	name = "Market_%s" % view.id
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 8)
	add_child(lines)

	_name_label.text = view.name
	_name_label.theme_type_variation = UiTheme.HEADING_LABEL
	lines.add_child(_name_label)
	_reach_label = UiTheme.wrapping_label(true)
	lines.add_child(_reach_label)

	var stats := UiTheme.flow(24)
	lines.add_child(stats)
	# Fixed widths keep the layout still as values change.
	_population_label = UiTheme.column_label(170)
	stats.add_child(_population_label)
	_income_label = UiTheme.column_label(120)
	stats.add_child(_income_label)
	_period_label = UiTheme.column_label(0, true)
	stats.add_child(_period_label)
	_capacity_label = UiTheme.wrapping_label()
	lines.add_child(_capacity_label)

	var invest := UiTheme.flow(12)
	lines.add_child(invest)
	for goal: MarketView.Investment in [MarketView.Investment.POPULATION, MarketView.Investment.INCOME]:
		var button := Button.new()
		button.name = "InvestPopulation" if goal == MarketView.Investment.POPULATION else "InvestIncome"
		button.pressed.connect(func() -> void: invest_pressed.emit(market_id, goal))
		invest.add_child(button)
		_invest_buttons[goal] = button
	var invest_hint := UiTheme.wrapping_label(true)
	invest_hint.text = "A community investment for population gives more capacity. One for income gives higher prices."
	lines.add_child(invest_hint)

	var legend := UiTheme.wrapping_label(true)
	legend.text = "Each color: its price, then its demand now and its demand forecast."
	lines.add_child(legend)
	var grid := CardGrid.new()
	grid.name = "Prices"
	grid.min_column_width = PRICE_COLUMN_WIDTH
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 6)
	lines.add_child(grid)
	for color in colors:
		grid.add_child(_price_cell(color))


## One color in the price grid: its symbol and name, its price, its demand,
## and its forecast.
func _price_cell(color: ColorDef) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.name = "Color_%s" % color.id
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override(&"separation", 8)
	var symbol := ColorSymbol.new().setup(color)
	symbol.custom_minimum_size = Vector2(24, 24)
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(symbol)
	var color_name := UiTheme.column_label(0, true)
	color_name.text = color.name
	color_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(color_name)
	var price := UiTheme.column_label(72)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.add_child(price)
	var demand := UiTheme.column_label(56)
	demand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.add_child(demand)
	var arrow := UiTheme.column_label(0, true)
	arrow.text = "→"
	item.add_child(arrow)
	var forecast := UiTheme.column_label(56, true)
	forecast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.add_child(forecast)
	_price_labels[color.id] = price
	_demand_labels[color.id] = demand
	_forecast_labels[color.id] = forecast
	return item


## Shows [param view] and the demand in [param forecast]. The prices show only
## while the row is on the screen. [param needed_tier_plural]
## is the plural name of the transport tier that the market needs, such as
## "Trucks", or "" when no tier reaches it.
func show_state(view: MarketView, needed_tier_plural: String, forecast: ForecastView) -> void:
	_reach_label.text = reach_text(view, needed_tier_plural)
	if view.is_open:
		_reach_label.remove_theme_color_override(&"font_color")
	else:
		_reach_label.add_theme_color_override(&"font_color", BLOCKED_COLOR)
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
	# The prices are most of the labels of the market section, so a row
	# shows them only while it is on the screen. The screen shows the row
	# again when it opens it.
	if not is_visible_in_tree():
		return
	for color_id in _price_labels:
		_price_labels[color_id].text = view.price(color_id).format()
		_demand_labels[color_id].text = format_demand(view.demand(color_id))
		_forecast_labels[color_id].text = format_demand(forecast.demand(market_id, color_id))


## Such as "Remoteness 2, open to trucks" or "Remoteness 4, needs trains".
static func reach_text(view: MarketView, needed_tier_plural: String) -> String:
	if needed_tier_plural.is_empty():
		return "Remoteness %d, no transport tier reaches it yet" % view.remoteness
	return "Remoteness %d, %s %s" % [view.remoteness, "open to" if view.is_open else "needs",
		needed_tier_plural.to_lower()]


## The text that shows the remoteness and the tier the market needs.
func reach_label_text() -> String:
	return _reach_label.text


## The price, demand, and forecast of [param color_id], such as "Price
## 31.47, demand 112%, forecast 110%".
func color_text(color_id: StringName) -> String:
	return "Price %s, demand %s, forecast %s" % [_price_labels[color_id].text,
		_demand_labels[color_id].text, _forecast_labels[color_id].text]


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
