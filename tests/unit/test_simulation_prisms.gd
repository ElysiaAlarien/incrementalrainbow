extends GutTest
## Prisms: the player buys them with money during a run, at a price that goes
## up with each prism (ADR-0003).

const SEED := 11


## Content with [param starting_money], factories that cost 10, and prisms that
## cost [param first_price], then [param growth] times the one before.
func _content(starting_money: float, first_price: float = 20, growth: float = 2.0) -> Content:
	return ContentFixture.make_with_balance(ContentFixture.balance_data(1000, 10,
		{"starting_money": starting_money, "first_price": first_price, "price_growth": growth}))


func test_a_new_game_has_no_prisms_and_shows_the_first_price() -> void:
	var sim := Simulation.new(_content(100), SEED)

	var prisms := sim.prisms()

	assert_eq(prisms.owned, 0)
	assert_eq(prisms.total_bought, 0)
	assert_true(prisms.next_price.equals(BigNumber.from_int(20)), "got %s" % prisms.next_price)


func test_buying_a_prism_costs_its_price() -> void:
	var sim := Simulation.new(_content(100), SEED)

	var result := sim.buy_prism()

	assert_true(result.ok, result.message)
	assert_eq(result.value, 1, "the value is the prisms owned")
	assert_true(sim.money().equals(BigNumber.from_int(80)), "got %s" % sim.money())
	assert_eq(sim.prisms().owned, 1)
	assert_eq(sim.prisms().total_bought, 1)


func test_the_price_goes_up_after_each_prism() -> void:
	var sim := Simulation.new(_content(1000), SEED)
	var prices: Array[String] = []

	for i in 4:
		prices.append(sim.prisms().next_price.format())
		assert_true(sim.buy_prism().ok)

	assert_eq(prices, ["20", "40", "80", "160"] as Array[String])
	assert_eq(sim.prisms().next_price.format(), "320")
	assert_true(sim.money().equals(BigNumber.from_int(1000 - 300)), "got %s" % sim.money())
	assert_eq(sim.prisms().owned, 4)
	assert_eq(sim.prisms().total_bought, 4)


func test_prices_are_whole_numbers_that_go_up() -> void:
	# 7 * 1.15^n is not whole, and the price rounds up.
	var sim := Simulation.new(_content(1_000_000, 7, 1.15), SEED)
	var last := BigNumber.ZERO

	for i in 30:
		var price := sim.prisms().next_price
		assert_true(price.equals(price.ceiled()), "price %s is whole" % price)
		assert_true(last.is_less_than(price), "price %s is more than %s" % [price, last])
		last = price
		assert_true(sim.buy_prism().ok)


func test_the_last_money_can_buy_a_prism() -> void:
	var sim := Simulation.new(_content(20), SEED)

	assert_true(sim.buy_prism().ok)

	assert_true(sim.money().is_zero(), "got %s" % sim.money())


func test_buying_a_prism_with_too_little_money_fails_and_changes_nothing() -> void:
	var sim := Simulation.new(_content(30), SEED)
	sim.buy_prism()
	var before := sim.snapshot()

	var result := sim.buy_prism()

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_MONEY)
	assert_string_contains(result.message, "A prism costs 40, but you have only 10.")
	assert_eq(sim.snapshot(), before)
	assert_eq(sim.prisms().owned, 1)


func test_changing_the_prism_view_does_not_change_the_game() -> void:
	var sim := Simulation.new(_content(100), SEED)
	var view := sim.prisms()

	view.owned = 9
	view.total_bought = 9

	assert_eq(sim.prisms().owned, 0)
	assert_eq(sim.prisms().total_bought, 0)
