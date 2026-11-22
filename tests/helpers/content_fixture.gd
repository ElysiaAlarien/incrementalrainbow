class_name ContentFixture
extends RefCounted
## Small content for tests, so tests do not depend on the game's data files.

const FACTORY_COST := 10
const PRICE := 5
const TRANSIT_TIME_MS := 5000
const SHIPMENT_COST := 2
const AUTOMATIC_COST := 20
const FIRST_PRISM_PRICE := 20
const INPUT_BAY_CAPACITY := 10
## The shortest and longest time between demand event starts in
## [method balance_data].
const EVENT_INTERVAL_MIN_MS := 5000
const EVENT_INTERVAL_MAX_MS := 10_000
## Each fixture market starts with this population and income. With the
## fixture balance, that gives a capacity of [constant CAPACITY] in each
## period of [constant PERIOD_MS], and prices at the base price.
const POPULATION := 1000
const INCOME := 100
const CAPACITY := 1000
const PERIOD_MS := 60_000
const INVESTMENT_COST := 10
const POPULATION_STEP := 100
const INCOME_STEP := 50
const WAREHOUSE_COST := 30
const WAREHOUSE_SPACE := 20
const LAB_COST := 30
## The tiers after carts in [method transport_data]: trucks reach remoteness
## 2 and trains reach 4. Carts reach only remoteness 0.
const TRUCK_PRICE := 30
const TRUCK_UPGRADE_COST := 5
const TRUCK_TRANSIT_TIME_MS := 2000
const TRUCK_SHIPMENT_COST := 3
const TRAIN_PRICE := 60
const TRAIN_UPGRADE_COST := 10
const TRAIN_TRANSIT_TIME_MS := 1000
const TRAIN_SHIPMENT_COST := 4
## 24 hours, as in the game data.
const MAX_OFFLINE_MS := 86_400_000
## The forecast accuracy with no forecast research, and the time ahead that the
## screen shows the forecast for, in [method balance_data].
const FORECAST_BASE_ACCURACY := 0.1
const FORECAST_HORIZON_MS := 10_000
## The prestige upgrades of [method prestige_upgrades_data]: quick_lines
## costs 1 prism and doubles the production speed, and seed_money costs 2
## prisms and adds 50 starting money.
const QUICK_LINES_PRICE := 1
const SEED_MONEY_PRICE := 2
const SEED_MONEY := 50


static func colors_data() -> Dictionary:
	return {"colors": [
		{"id": "red", "name": "Red", "symbol": "square", "display": "#d64545", "recipe": {}},
		{"id": "yellow", "name": "Yellow", "symbol": "triangle", "display": "#f2c230", "recipe": {}},
		{"id": "blue", "name": "Blue", "symbol": "circle", "display": "#3a6fd8", "recipe": {}},
	]}


## The three primary colors, plus green (1 yellow and 1 blue), purple (2 red
## and 1 blue, to test counts above 1), a tertiary color that research
## unlocks (blue-green: 1 blue and 1 green), and brown (red, yellow, and blue),
## which research unlocks too.
static func mixed_colors_data() -> Dictionary:
	var data := colors_data()
	data.colors.append_array([
		{"id": "green", "name": "Green", "symbol": "diamond", "display": "#3fa34d",
			"recipe": {"yellow": 1, "blue": 1}},
		{"id": "purple", "name": "Purple", "symbol": "hexagon", "display": "#8a4fc4",
			"recipe": {"red": 2, "blue": 1}},
		{"id": "blue_green", "name": "Blue-green", "symbol": "arrow", "display": "#2a9c94",
			"recipe": {"blue": 1, "green": 1}, "unlock": "research"},
		{"id": "brown", "name": "Brown", "symbol": "star", "display": "#8b5a33",
			"recipe": {"red": 1, "yellow": 1, "blue": 1}, "unlock": "research"},
	])
	return data


## The test colors, plus white, a base color that a prestige upgrade
## unlocks.
static func prestige_colors_data() -> Dictionary:
	var data := colors_data()
	data.colors.append({"id": "white", "name": "White", "symbol": "pentagon", "display": "#f4f4f4",
		"recipe": {}, "unlock": "prestige_upgrade"})
	return data


## Balance data: 100 starting money, factories that cost 10, input bays
## of 10, a flat
## production line cost of 10, prisms that cost 20, then 40, 80, and so on, and
## demand that stays at 1 (no drift and no saturation), so that prices stay at
## the base price. A demand event starts each 5 to 10 s, but [method data]
## has no demand events unless a test gives some. Markets: a capacity of 1 widget for each person, so the
## fixture markets have a capacity of [constant CAPACITY] in each period of
## [constant PERIOD_MS]; prices at the base price at [constant INCOME]; and
## community investments that cost 10, then 20, 40, and so on.
## Warehouses cost 30, hold 20, and are unlocked from the start.
## [param overrides] replaces values by key, such as
## [code]{"starting_money": 15, "production_line_cost_growth": 2.0}[/code].
## Keys are unique across the sections.
## [method demand_overrides] turns drift and saturation on.
static func balance_data(widget_time_ms: int = 1000, output_bay_capacity: int = 10,
		overrides: Dictionary = {}) -> Dictionary:
	var run := {"starting_money": 100}
	var factory := {
		"widget_time_ms": widget_time_ms,
		"output_bay_capacity": output_bay_capacity,
		"input_bay_capacity": INPUT_BAY_CAPACITY,
		"build_cost": FACTORY_COST,
		"production_line_cost": 10,
		"production_line_cost_growth": 1.0,
	}
	var demand := {
		"drift_period_ms": 10_000,
		"drift_amplitude": 0.0,
		"saturation_ms_per_widget": 0,
		"saturation_half_widgets": 10,
		"event_interval_min_ms": EVENT_INTERVAL_MIN_MS,
		"event_interval_max_ms": EVENT_INTERVAL_MAX_MS,
	}
	var prism := {"first_price": FIRST_PRISM_PRICE, "price_growth": 2.0}
	var market := {
		"period_ms": PERIOD_MS,
		"capacity_per_population": 1.0,
		"reference_income": INCOME,
		"investment_cost": INVESTMENT_COST,
		"investment_cost_growth": 2.0,
		"population_step": POPULATION_STEP,
		"income_step": INCOME_STEP,
	}
	var warehouse := {"cost": WAREHOUSE_COST, "space": WAREHOUSE_SPACE, "unlock_factory_count": 0}
	var offline := {"max_time_away_ms": MAX_OFFLINE_MS}
	var forecast := {"base_accuracy": FORECAST_BASE_ACCURACY, "horizon_ms": FORECAST_HORIZON_MS}
	for key: String in overrides:
		var section: Dictionary = {}
		for candidate: Dictionary in [run, factory, demand, prism, market, warehouse, offline, forecast]:
			if candidate.has(key):
				section = candidate
		assert(not section.is_empty(), "unknown balance key %s" % key)
		section[key] = overrides[key]
	return {"run": run, "factory": factory, "demand": demand, "prism": prism, "market": market,
		"warehouse": warehouse, "offline": offline, "forecast": forecast}


## Overrides for [method balance_data] that turn on drift (up to 30%, with a
## knot each 10 s) and saturation (10 recent widgets halve demand, and each
## widget takes 1 s to recover).
static func demand_overrides() -> Dictionary:
	return {"drift_amplitude": 0.3, "saturation_ms_per_widget": 1000}


## Markets, one for each of [param ids] (by default only "millbrook"), that
## each pay a base price of [param price] for each color in [param colors], and
## each start with [param population] and [param income]. Market [code]i[/code]
## has the remoteness [code]remoteness[i][/code], or 0.
static func markets_data(price: float = PRICE, colors: Dictionary = colors_data(),
		ids: PackedStringArray = ["millbrook"], population: int = POPULATION,
		income: int = INCOME, remoteness: PackedInt32Array = []) -> Dictionary:
	var prices := {}
	for color: Dictionary in colors.colors:
		prices[color.id] = price
	var markets := []
	for i in ids.size():
		markets.append({"id": ids[i], "name": ids[i].capitalize(), "population": population,
			"income": income, "prices": prices, "remoteness": remoteness[i] if i < remoteness.size() else 0})
	return {"markets": markets}


## Rules for the "generator" object of markets.json: the game shows
## [param closed_markets_shown] closed markets. Each generated market is 1 more
## remote than the one before it. Population is 1000 plus 100 for each step of
## remoteness, and income 100 plus 10, each within 20% of that. One random
## color has double the base price. Names come from two starts and two ends,
## so the fifth market has the name of the first with a 2. [param overrides]
## replaces values by key.
static func generator_data(closed_markets_shown: int = 2, overrides: Dictionary = {}) -> Dictionary:
	var rules := {
		"closed_markets_shown": closed_markets_shown,
		"remoteness_step": 1,
		"population_base": POPULATION,
		"population_per_remoteness": 100,
		"income_base": INCOME,
		"income_per_remoteness": 10,
		"spread": 0.2,
		"favored_colors": 1,
		"favored_price_factor": 2.0,
		"name_starts": ["North", "South"],
		"name_ends": ["port", "field"],
	}
	for key: String in overrides:
		assert(rules.has(key), "unknown generator key %s" % key)
		rules[key] = overrides[key]
	return rules


## [method remote_markets_data] with the market generator of
## [method generator_data].
static func generated_markets_data(colors: Dictionary = colors_data(),
		closed_markets_shown: int = 2) -> Dictionary:
	var data := remote_markets_data(colors)
	data.generator = generator_data(closed_markets_shown)
	return data


## Three markets for transport tier tests: millbrook (remoteness 0, carts reach
## it), farpoint (2, trucks), and lastport (4, trains).
static func remote_markets_data(colors: Dictionary = colors_data()) -> Dictionary:
	return markets_data(PRICE, colors, ["millbrook", "farpoint", "lastport"], POPULATION, INCOME, [0, 2, 4])


## Three transport tiers: carts (reach remoteness 0), with [param transit_time_ms]
## and [param shipment_cost]; then trucks (reach 2) and trains (reach 4), with
## the TRUCK_ and TRAIN_ constants. Automatic transport costs
## [param automatic_cost].
static func transport_data(transit_time_ms: int = TRANSIT_TIME_MS,
		shipment_cost: float = SHIPMENT_COST, automatic_cost: float = AUTOMATIC_COST) -> Dictionary:
	return {"automatic_transport_cost": automatic_cost, "tiers": [
		{"id": "cart", "name": "Cart", "plural_name": "Carts", "max_remoteness": 0, "transit_time_ms": transit_time_ms,
			"shipment_cost": shipment_cost},
		{"id": "truck", "name": "Truck", "plural_name": "Trucks", "max_remoteness": 2, "transit_time_ms": TRUCK_TRANSIT_TIME_MS,
			"shipment_cost": TRUCK_SHIPMENT_COST, "price": TRUCK_PRICE, "vehicle_upgrade_cost": TRUCK_UPGRADE_COST},
		{"id": "train", "name": "Train", "plural_name": "Trains", "max_remoteness": 4, "transit_time_ms": TRAIN_TRANSIT_TIME_MS,
			"shipment_cost": TRAIN_SHIPMENT_COST, "price": TRAIN_PRICE, "vehicle_upgrade_cost": TRAIN_UPGRADE_COST},
	]}


## Demand events: a spike of red and blue by 0.5 for 20 s ("red_blue_spike"),
## and a crash of yellow by 0.4 for 30 s ("yellow_crash"). [param ids] picks
## which ones, in order.
static func demand_events_data(ids: PackedStringArray = ["red_blue_spike", "yellow_crash"]) -> Dictionary:
	var all := {
		"red_blue_spike": {"id": "red_blue_spike", "name": "Red and blue spike", "colors": ["red", "blue"],
			"direction": "spike", "size": 0.5, "duration_ms": 20_000},
		"yellow_crash": {"id": "yellow_crash", "name": "Yellow crash", "colors": ["yellow"],
			"direction": "crash", "size": 0.4, "duration_ms": 30_000},
	}
	var events := []
	for id in ids:
		events.append(all[id])
	return {"events": events}


## Labs that cost 30, and research for the colors in [param colors] that
## research unlocks. With the colors of [method mixed_colors_data]:
## "earth_tones" costs 2 red, 2 yellow, and 2 blue and unlocks brown, and
## "cool_mixes" requires earth_tones, costs 3 green, and unlocks blue-green.
## With no such colors, there is no research.
static func research_data(colors: Dictionary = colors_data()) -> Dictionary:
	var ids: Array = colors.colors.map(func(c: Dictionary) -> String: return c.id)
	var research := []
	if ids.has("brown"):
		research.append({"id": "earth_tones", "name": "Earth tones",
			"cost": {"red": 2, "yellow": 2, "blue": 2}, "unlocks": {"colors": ["brown"]}})
	if ids.has("blue_green"):
		research.append({"id": "cool_mixes", "name": "Cool mixes", "requires": ["earth_tones"],
			"cost": {"green": 3}, "unlocks": {"colors": ["blue_green"]}})
	return {"lab_build_cost": LAB_COST, "research": research}


## Prestige upgrades: "quick_lines" (doubles the production speed) and
## "seed_money" (adds [constant SEED_MONEY] starting money), at the prices of
## the constants. When [param colors] has white (see
## [method prestige_colors_data]), also "white_light", which costs 1 prism and
## unlocks white.
static func prestige_upgrades_data(colors: Dictionary = colors_data()) -> Dictionary:
	var upgrades := [
		{"id": "quick_lines", "name": "Quick lines", "price": QUICK_LINES_PRICE,
			"bonuses": {"production_speed": 2.0}},
		{"id": "seed_money", "name": "Seed money", "price": SEED_MONEY_PRICE,
			"bonuses": {"starting_money": SEED_MONEY}},
	]
	var ids: Array = colors.colors.map(func(c: Dictionary) -> String: return c.id)
	if ids.has("white"):
		upgrades.append({"id": "white_light", "name": "White light", "price": 1,
			"unlocks": {"colors": ["white"]}})
	return {"upgrades": upgrades}


## Data for [method Content.from_data], with each section replaceable. When
## [param markets] is null, one market prices every color in [param colors].
## By default there are no demand events. When [param research] or
## [param prestige_upgrades] is null, it comes from [method research_data] or
## [method prestige_upgrades_data] for [param colors].
static func data(colors: Dictionary = colors_data(), balance: Dictionary = balance_data(),
		markets: Variant = null, transport: Dictionary = transport_data(),
		demand_events: Dictionary = {"events": []}, research: Variant = null,
		prestige_upgrades: Variant = null) -> Dictionary:
	if markets == null:
		markets = markets_data(PRICE, colors)
	if research == null:
		research = research_data(colors)
	if prestige_upgrades == null:
		prestige_upgrades = prestige_upgrades_data(colors)
	return {"colors": colors, "balance": balance, "markets": markets, "transport": transport,
		"demand_events": demand_events, "research": research, "prestige_upgrades": prestige_upgrades}


## Content with one widget per [param widget_time_ms] for each production line,
## an output bay of [param output_bay_capacity], 100 starting money, and a flat
## production line cost of 10.
static func make(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	return make_with_balance(balance_data(widget_time_ms, output_bay_capacity))


## Like [method make], with the colors of [method mixed_colors_data].
static func make_mixed(widget_time_ms: int = 1000, output_bay_capacity: int = 10) -> Content:
	return from_data(data(mixed_colors_data(), balance_data(widget_time_ms, output_bay_capacity)))


## The content that the save fixtures in tests/fixtures/saves/ load with: like
## [code]make_mixed(700, 6)[/code], with the demand events of
## [method demand_events_data] and the market generator of
## [method generator_data], which shows 1 closed market. The first generated
## market has remoteness 1, so trucks reach two of them.
static func make_for_saves() -> Content:
	var colors := mixed_colors_data()
	var markets := markets_data(PRICE, colors)
	markets.generator = generator_data(1)
	return from_data(data(colors, balance_data(700, 6), markets, transport_data(),
		demand_events_data()))


## Content with the test colors and [param balance] from [method balance_data].
static func make_with_balance(balance: Dictionary) -> Content:
	return from_data(data(colors_data(), balance))


## Content from [param p_data], which must be valid.
static func from_data(p_data: Dictionary) -> Content:
	var content := Content.from_data(p_data)
	assert(content.errors.is_empty(), "test content is valid: %s" % "; ".join(content.errors))
	return content
