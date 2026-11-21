extends GutTest
## Market capacity, population, income, and community investment. A market buys
## at most its capacity of widgets, of all colors, in one period. Capacity comes
## from population, and prices come from income.

const SEED := 21
const MARKET := &"millbrook"
## The fixture market has a population of 7 and 1 widget of capacity for each
## person, so a capacity of 7 in each period.
const CAPACITY := 7
const PERIOD_MS := 20_000
const PRICE := 5
const TRANSIT_MS := 5000
const SHIPMENT_COST := 2


## One widget each second, an output bay of 10, factories that cost 10,
## shipments that cost 2 and take 5 s, and a market with a capacity of 7 in each
## period of 20 s. A community investment adds 3 people or 50 income, and costs
## 10, then 20, 40, and so on.
func _content(overrides: Dictionary = {}, ids: PackedStringArray = [MARKET]) -> Content:
	var values := {"period_ms": PERIOD_MS, "population_step": 3}
	values.merge(overrides, true)
	var colors := ContentFixture.colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, values),
		ContentFixture.markets_data(PRICE, colors, ids, CAPACITY),
		ContentFixture.transport_data(TRANSIT_MS, SHIPMENT_COST)))


func _sim(overrides: Dictionary = {}) -> Simulation:
	return Simulation.new(_content(overrides), SEED)


## A red factory with a link to the market. Returns the link id.
func _red_link(sim: Simulation, color: StringName = &"red", market: StringName = MARKET) -> int:
	var factory := sim.build_factory(color)
	assert_true(factory.ok, factory.message)
	var link := sim.make_link(factory.value, market)
	assert_true(link.ok, link.message)
	return link.value


func _assert_money(sim: Simulation, expected: float) -> void:
	assert_true(sim.money().equals(BigNumber.from_float(expected)),
		"money should be %s, got %s" % [expected, sim.money()])


# --- Queries --------------------------------------------------------------------

func test_a_query_gives_population_income_and_capacity_of_each_market() -> void:
	var sim := Simulation.new(_content({}, ["millbrook", "ashford"]), SEED)
	sim.tick(4000)

	var markets := sim.markets()

	assert_eq(markets.size(), 2)
	for view in markets:
		assert_eq(view.population, CAPACITY)
		assert_eq(view.income, ContentFixture.INCOME)
		assert_eq(view.capacity, CAPACITY)
		assert_eq(view.capacity_used, 0)
		assert_eq(view.capacity_in_transit, 0)
		assert_eq(view.capacity_left, CAPACITY)
		assert_eq(view.period_ends_in_ms, PERIOD_MS - 4000)
		assert_eq(view.investment_cost(MarketView.Investment.POPULATION).format(), "10")
		assert_eq(view.investment_cost(MarketView.Investment.INCOME).format(), "10")


func test_capacity_comes_from_population() -> void:
	var small := _sim({"capacity_per_population": 2.0})
	var large := Simulation.new(ContentFixture.from_data(ContentFixture.data(ContentFixture.colors_data(),
		ContentFixture.balance_data(1000, 10, {"capacity_per_population": 2.0}),
		ContentFixture.markets_data(PRICE, ContentFixture.colors_data(), [MARKET], 20))), SEED)

	assert_eq(small.market(MARKET).capacity, 14, "7 people, 2 widgets each")
	assert_eq(large.market(MARKET).capacity, 40, "20 people, 2 widgets each")


# --- Shipment size ----------------------------------------------------------------

func test_a_shipment_carries_no_more_than_the_capacity_left() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.tick(10_000)

	var result := sim.start_shipment(link_id)

	assert_true(result.ok, result.message)
	assert_eq(result.value, CAPACITY, "10 widgets are ready, but the market has room for 7")
	assert_eq(sim.factory(1).output_bay_count, 3, "the rest stay in the output bay")
	var market := sim.market(MARKET)
	assert_eq(market.capacity_in_transit, CAPACITY)
	assert_eq(market.capacity_used, 0, "nothing is sold yet")
	assert_eq(market.capacity_left, 0)


func test_with_no_capacity_left_a_shipment_does_not_start_and_shows_why() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.tick(10_000)
	sim.start_shipment(link_id)
	var before := sim.snapshot()

	var result := sim.start_shipment(link_id)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOTHING_TO_SHIP)
	assert_string_contains(result.message, "Millbrook has no capacity left in this period")
	assert_eq(sim.snapshot(), before, "a failed shipment changes nothing")
	assert_eq(sim.market(MARKET).capacity_left, 0, "the market query shows why")


func test_all_colors_share_the_capacity() -> void:
	var sim := _sim()
	var red := _red_link(sim)
	var blue := _red_link(sim, &"blue")
	sim.tick(5000)

	assert_eq(sim.start_shipment(red).value, 5)
	assert_eq(sim.start_shipment(blue).value, 2, "red took 5 of the 7")
	assert_false(sim.start_shipment(blue).ok)


func test_capacity_of_one_market_does_not_limit_another() -> void:
	var sim := Simulation.new(_content({}, ["millbrook", "ashford"]), SEED)
	var to_millbrook := _red_link(sim)
	var to_ashford: int = sim.make_link(1, &"ashford").value
	sim.tick(10_000)

	assert_eq(sim.start_shipment(to_millbrook).value, CAPACITY)
	assert_eq(sim.start_shipment(to_ashford).value, 3, "the last 3 widgets go to Ashford")
	assert_eq(sim.market(&"ashford").capacity_left, CAPACITY - 3)


# --- Sales in a period ----------------------------------------------------------

func test_a_market_sells_no_more_than_its_capacity_in_one_period() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.tick(10_000)
	sim.start_shipment(link_id)
	sim.tick(TRANSIT_MS)

	var market := sim.market(MARKET)
	assert_eq(market.capacity_used, CAPACITY, "the 7 widgets sold")
	assert_eq(market.capacity_in_transit, 0)
	_assert_money(sim, 100 - 10 - SHIPMENT_COST + CAPACITY * PRICE)
	assert_false(sim.start_shipment(link_id).ok, "the market bought its capacity in this period")
	sim.tick(PERIOD_MS - 15_000 - 1)
	assert_false(sim.start_shipment(link_id).ok, "still the same period")


func test_capacity_used_goes_back_to_zero_at_the_start_of_each_period() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.tick(10_000)
	sim.start_shipment(link_id)
	sim.tick(PERIOD_MS - 10_000)

	var market := sim.market(MARKET)
	assert_eq(market.capacity_used, 0, "a new period starts at 20 s")
	assert_eq(market.period_ends_in_ms, PERIOD_MS)
	assert_eq(sim.start_shipment(link_id).value, CAPACITY, "10 widgets are ready, the market takes 7")
	sim.tick(TRANSIT_MS)
	assert_eq(sim.market(MARKET).capacity_used, CAPACITY)


func test_widgets_on_the_way_at_a_new_period_count_against_it() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.tick(18_000)
	assert_eq(sim.start_shipment(link_id).value, CAPACITY, "leaves at 18 s, arrives at 23 s")
	sim.tick(2000)

	var market := sim.market(MARKET)
	assert_eq([market.capacity_used, market.capacity_in_transit, market.capacity_left], [0, CAPACITY, 0])
	assert_false(sim.start_shipment(link_id).ok, "the shipment on the way holds the capacity")
	sim.tick(3000)
	market = sim.market(MARKET)
	assert_eq([market.capacity_used, market.capacity_in_transit], [CAPACITY, 0],
		"the sale at 23 s counts in the period that it arrives in")


func test_an_automatic_link_to_a_full_market_sends_nothing_and_shows_why() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.tick(10_000)
	assert_true(sim.buy_automatic_transport(link_id).ok)
	sim.tick(TRANSIT_MS + 1)

	assert_eq(sim.link(link_id).automatic, LinkView.Automatic.NOTHING_TO_SHIP,
		"the start at 10 s shipped 7, they sold at 15 s, and the market has no capacity left")
	assert_eq(sim.market(MARKET).capacity_left, 0, "the market query shows why")
	sim.tick(PERIOD_MS - 15_001 + 1)
	assert_eq(sim.link(link_id).automatic, LinkView.Automatic.SHIPPED, "the start at 20 s is in a new period")
	assert_eq(sim.market(MARKET).capacity_in_transit, CAPACITY)


# --- Community investment ---------------------------------------------------------

func test_a_community_investment_for_population_grows_population_and_capacity() -> void:
	var sim := _sim()

	var result := sim.make_community_investment(MARKET, MarketView.Investment.POPULATION)

	assert_true(result.ok, result.message)
	assert_eq(result.value, CAPACITY + 3, "the new population")
	var market := sim.market(MARKET)
	assert_eq(market.population, CAPACITY + 3)
	assert_eq(market.capacity, CAPACITY + 3, "a higher population gives a higher capacity")
	assert_eq(market.income, ContentFixture.INCOME, "income does not change")
	_assert_money(sim, 100 - ContentFixture.INVESTMENT_COST)


func test_more_population_lets_a_shipment_carry_more() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.tick(10_000)
	sim.make_community_investment(MARKET, MarketView.Investment.POPULATION)

	assert_eq(sim.start_shipment(link_id).value, 10)


func test_a_community_investment_for_income_grows_income_and_prices() -> void:
	var sim := _sim()
	var before := sim.market(MARKET).price(&"red")

	var result := sim.make_community_investment(MARKET, MarketView.Investment.INCOME)

	assert_true(result.ok, result.message)
	var market := sim.market(MARKET)
	assert_eq(result.value, ContentFixture.INCOME + ContentFixture.INCOME_STEP)
	assert_eq(market.income, ContentFixture.INCOME + ContentFixture.INCOME_STEP)
	assert_eq(market.population, CAPACITY, "population does not change")
	assert_true(before.equals(BigNumber.from_int(PRICE)), "the base price at the reference income")
	assert_true(market.price(&"red").equals(BigNumber.from_float(PRICE * 1.5)),
		"income 150 pays 1.5 times the price of income 100, got %s" % market.price(&"red"))


func test_a_sale_uses_the_price_from_income() -> void:
	var sim := _sim()
	var link_id := _red_link(sim)
	sim.make_community_investment(MARKET, MarketView.Investment.INCOME)
	sim.tick(4000)
	sim.start_shipment(link_id)
	sim.tick(TRANSIT_MS)

	_assert_money(sim, 100 - 10 - ContentFixture.INVESTMENT_COST - SHIPMENT_COST + 4 * PRICE * 1.5)


func test_each_community_investment_of_a_kind_costs_more() -> void:
	var sim := _sim({"starting_money": 1000})
	sim.make_community_investment(MARKET, MarketView.Investment.POPULATION)
	sim.make_community_investment(MARKET, MarketView.Investment.POPULATION)

	var market := sim.market(MARKET)
	assert_eq(market.investment_cost(MarketView.Investment.POPULATION).format(), "40")
	assert_eq(market.investment_cost(MarketView.Investment.INCOME).format(), "10",
		"each kind has its own cost")
	_assert_money(sim, 1000 - 10 - 20)
	assert_eq(market.population, CAPACITY + 6)


func test_a_community_investment_with_too_little_money_fails_and_changes_nothing() -> void:
	var sim := _sim({"starting_money": 9})
	var before := sim.snapshot()

	for goal: MarketView.Investment in [MarketView.Investment.POPULATION, MarketView.Investment.INCOME]:
		var result := sim.make_community_investment(MARKET, goal)
		assert_false(result.ok)
		assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_MONEY)
		assert_string_contains(result.message, "costs 10, but you have only 9")
	assert_eq(sim.snapshot(), before)


func test_the_last_money_can_make_a_community_investment() -> void:
	var sim := _sim({"starting_money": 10})

	assert_true(sim.make_community_investment(MARKET, MarketView.Investment.INCOME).ok)
	_assert_money(sim, 0)


func test_a_community_investment_in_an_unknown_market_fails_and_changes_nothing() -> void:
	var sim := _sim()
	var before := sim.snapshot()

	var result := sim.make_community_investment(&"nowhere", MarketView.Investment.POPULATION)

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_MARKET)
	assert_eq(sim.snapshot(), before)


func test_a_community_investment_is_for_one_market_only() -> void:
	var sim := Simulation.new(_content({}, ["millbrook", "ashford"]), SEED)

	sim.make_community_investment(&"ashford", MarketView.Investment.POPULATION)

	assert_eq(sim.market(MARKET).population, CAPACITY)
	assert_eq(sim.market(&"ashford").population, CAPACITY + 3)
	assert_eq(sim.market(MARKET).investment_cost(MarketView.Investment.POPULATION).format(), "10")


# --- Ticks ------------------------------------------------------------------------

## A game with an automatic link and a manual link to a market with a small
## capacity, so that capacity limits shipments in many periods.
func _busy_game() -> Simulation:
	var sim := _sim({"starting_money": 1000})
	var automatic := _red_link(sim)
	_red_link(sim, &"blue")
	sim.buy_automatic_transport(automatic)
	return sim


func _play(sim: Simulation, ticks: Array[int]) -> void:
	for duration in ticks:
		sim.tick(duration)
		sim.start_shipment(2)


func test_one_long_tick_gives_the_same_state_as_many_short_ticks() -> void:
	var long := _busy_game()
	var short := _busy_game()

	long.tick(3 * PERIOD_MS + 6234)
	for i in 3 * PERIOD_MS / 1000:
		short.tick(1000)
	short.tick(6234)

	assert_eq(short.snapshot(), long.snapshot())
	assert_gt(long.market(MARKET).capacity_used, 0, "the shipment that left at 60 s sold in the last period")


func test_ticks_that_end_on_a_period_boundary_give_the_same_state() -> void:
	var a := _busy_game()
	var b := _busy_game()

	_play(a, [PERIOD_MS, PERIOD_MS, 7000])
	_play(b, [PERIOD_MS - 1, 1, PERIOD_MS - 3000, 3000, 7000])

	assert_eq(a.snapshot(), b.snapshot())
