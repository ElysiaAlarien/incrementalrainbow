class_name QueryResults
extends RefCounted
## The results of the market and forecast queries in a fixed game, as exact
## text, for the test that the queries give the same results as before (#55).
##
## [method record] plays the same game each time and returns label to the
## SHA-256 of the text of each query. The text has the bits of each float, so
## any change of a value changes the hash. tests/fixtures/query_results.json
## holds the hashes from the queries before #55 made them faster.
## tools/make_query_results.gd writes that file again.

const FIXTURE_PATH := "res://tests/fixtures/query_results.json"
const SEED := 23
const MARKETS: PackedStringArray = ["millbrook", "farpoint", "lastport", "dunmore"]
## Times ahead for the forecast: none, less than one drift period, one drift
## period, and some periods.
const AHEADS_MS: Array[int] = [0, 2500, 10_000, 35_000]
const GENERATED_AFTER_LOAD := 12


## Content with the colors of [method ContentFixture.tints_and_shades_colors_data],
## four hand-made markets with other base prices for each color, generated
## markets, all transport tiers up to the portal, drift, saturation, and demand
## events. The drift period and the forecast horizon are both 10 s, as in the
## game data.
static func content() -> Content:
	var colors := ContentFixture.tints_and_shades_colors_data()
	var markets := ContentFixture.markets_data(ContentFixture.PRICE, colors, MARKETS,
		ContentFixture.POPULATION, ContentFixture.INCOME, [0, 1, 2, 4])
	for i in markets.markets.size():
		var prices := {}
		var j := 0
		for color: Dictionary in colors.colors:
			prices[color.id] = 3.0 + 1.7 * i + 2.3 * j
			j += 1
		markets.markets[i].prices = prices
	markets.generator = ContentFixture.generator_data(2)
	var overrides := ContentFixture.demand_overrides()
	overrides.starting_money = 1_000_000
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, overrides), markets,
		ContentFixture.portal_transport_data(), ContentFixture.demand_events_data(), null,
		ContentFixture.tints_and_shades_upgrades_data()))


## Label to the SHA-256 of the text of each query, in the order of the game.
static func record() -> Dictionary:
	var hashes := {}
	var game_content := content()
	var sim := Simulation.new(game_content, SEED)
	for i in 2:
		_must(sim.buy_transport_tier())
	for color: StringName in [&"red", &"yellow", &"blue"]:
		var factory: int = _must(sim.build_factory(color))
		for market: StringName in [&"millbrook", &"farpoint"]:
			_must(sim.buy_automatic_transport(_must(sim.make_link(factory, market))))
	_query(sim, "start", hashes)
	# Before and on a knot of drift, with sales and saturation.
	for at_ms: int in [4000, 9999, 10_000, 23_456]:
		sim.tick(at_ms - sim.time_ms())
		_query(sim, "at %d" % at_ms, hashes)
	_must(sim.make_community_investment(&"millbrook", MarketView.Investment.INCOME))
	_must(sim.make_community_investment(&"farpoint", MarketView.Investment.POPULATION))
	_query(sim, "after investments", hashes)
	var loaded := load_with_generated_markets(game_content, sim, GENERATED_AFTER_LOAD)
	_query(loaded, "after a load", hashes)
	_must(loaded.buy_transport_tier())
	loaded.tick(7777)
	_query(loaded, "with the portal", hashes)
	loaded.tick(90_000)
	_query(loaded, "later", hashes)
	return hashes


## A save of [param sim] loaded with [param count] generated markets.
static func load_with_generated_markets(p_content: Content, sim: Simulation, count: int) -> Simulation:
	var save: Dictionary = JSON.parse_string(SaveCodec.encode(sim, 0))
	save.state.generated_markets = count
	var result := SaveCodec.decode(p_content, JSON.stringify(save, "", true, true))
	assert(result.ok, result.message)
	return result.simulation


## Asks for the forecast at each time ahead and for the markets, in both
## orders and twice, and for one market.
static func _query(sim: Simulation, label: String, hashes: Dictionary) -> void:
	for ahead_ms in AHEADS_MS:
		hashes["%s: forecast %d" % [label, ahead_ms]] = forecast_text(sim.forecast(ahead_ms)).sha256_text()
		hashes["%s: markets after forecast %d" % [label, ahead_ms]] = markets_text(sim.markets()).sha256_text()
	hashes["%s: markets again" % label] = markets_text(sim.markets()).sha256_text()
	hashes["%s: forecast after markets" % label] = forecast_text(
		sim.forecast(sim.forecast_horizon_ms())).sha256_text()
	hashes["%s: one market" % label] = markets_text([sim.market(&"farpoint")]).sha256_text()


static func forecast_text(view: ForecastView) -> String:
	var lines := PackedStringArray(["%d %d %s" % [view.at_ms, view.ahead_ms, _bits(view.accuracy)]])
	for market_id: StringName in view.demands:
		var colors: Dictionary = view.demands[market_id]
		for color: StringName in colors:
			lines.append("%s %s %s" % [market_id, color, _bits(colors[color])])
	return "\n".join(lines)


static func markets_text(views: Array) -> String:
	var lines := PackedStringArray()
	for view: MarketView in views:
		lines.append(" ".join([view.id, view.name, view.population, view.income, view.capacity,
			view.capacity_used, view.capacity_in_transit, view.capacity_left, view.period_ends_in_ms,
			_big(view.population_investment_cost), _big(view.income_investment_cost), view.remoteness,
			view.needed_tier, view.is_open]))
		for color: StringName in view.demands:
			lines.append("%s %s" % [color, _bits(view.demands[color])])
		for color: StringName in view.prices:
			lines.append("%s %s" % [color, _big(view.prices[color])])
	return "\n".join(lines)


## The exact bits of [param value].
static func _bits(value: float) -> String:
	return PackedFloat64Array([value]).to_byte_array().hex_encode()


static func _big(value: BigNumber) -> String:
	return "%s,%d" % [_bits(value.mantissa), value.exponent]


static func _must(result: CommandResult) -> Variant:
	assert(result.ok, result.message)
	return result.value
