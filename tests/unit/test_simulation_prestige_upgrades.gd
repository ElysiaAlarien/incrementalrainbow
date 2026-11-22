extends GutTest
## Prestige upgrades: the player buys them with prisms, and they last across
## all later runs. They give bonuses (production speed and starting money) and
## unlock colors.

const SEED := 20


## One widget per second for each line, 1000 starting money, prisms that
## cost 20, then 40, 80, and so on, white (a prestige upgrade unlocks it), and
## the upgrades of [method ContentFixture.prestige_upgrades_data].
func _content(upgrades: Variant = null) -> Content:
	var colors := ContentFixture.prestige_colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, {"starting_money": 1000}), null, ContentFixture.transport_data(),
		{"events": []}, null, upgrades))


## A new game in which the player bought [param prisms] prisms.
func _sim(prisms: int = 3, content: Content = _content()) -> Simulation:
	var sim := Simulation.new(content, SEED)
	for i in prisms:
		assert_true(sim.buy_prism().ok)
	return sim


func _ok(result: CommandResult, what: String) -> Variant:
	assert_true(result.ok, "%s: %s" % [what, result.message])
	return result.value


func test_buying_an_upgrade_spends_its_price_in_prisms() -> void:
	var sim := _sim(3)

	var result := sim.buy_prestige_upgrade(&"seed_money")

	assert_true(result.ok, result.message)
	assert_eq(result.value, 3 - ContentFixture.SEED_MONEY_PRICE, "the value is the prisms left")
	assert_eq(sim.prisms().owned, 3 - ContentFixture.SEED_MONEY_PRICE)
	assert_eq(sim.prisms().total_bought, 3, "the prism price does not change")
	assert_true(sim.prestige_upgrade(&"seed_money").owned)
	assert_false(sim.prestige_upgrade(&"quick_lines").owned)


func test_an_upgrade_with_too_few_prisms_fails_with_a_reason() -> void:
	var sim := _sim(1)
	var before := sim.snapshot()

	var result := sim.buy_prestige_upgrade(&"seed_money")

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_PRISMS)
	assert_eq(result.message, "Seed money costs 2 prisms, but you have only 1 prism.")
	assert_eq(sim.snapshot(), before)


func test_an_upgrade_with_no_prisms_fails() -> void:
	var sim := _sim(0)

	var result := sim.buy_prestige_upgrade(&"quick_lines")

	assert_eq(result.reason, CommandResult.Reason.NOT_ENOUGH_PRISMS)
	assert_eq(result.message, "Quick lines costs 1 prism, but you have only 0 prisms.")


func test_an_unknown_upgrade_fails() -> void:
	var sim := _sim()
	var before := sim.snapshot()

	var result := sim.buy_prestige_upgrade(&"magic")

	assert_eq(result.reason, CommandResult.Reason.UNKNOWN_PRESTIGE_UPGRADE)
	assert_eq(result.message, "There is no prestige upgrade \"magic\".")
	assert_eq(sim.snapshot(), before)


func test_an_owned_upgrade_cannot_be_bought_again() -> void:
	var sim := _sim(3)
	_ok(sim.buy_prestige_upgrade(&"quick_lines"), "first")
	var before := sim.snapshot()

	var result := sim.buy_prestige_upgrade(&"quick_lines")

	assert_eq(result.reason, CommandResult.Reason.PRESTIGE_UPGRADE_OWNED)
	assert_eq(result.message, "You own Quick lines already.")
	assert_eq(sim.snapshot(), before)


func test_a_production_speed_upgrade_has_its_effect_at_once() -> void:
	var sim := _sim()
	var factory: int = _ok(sim.build_factory(&"red"), "build")
	sim.tick(500)
	assert_eq(sim.factory(factory).output_bay_count, 0, "half a widget at the old speed")

	_ok(sim.buy_prestige_upgrade(&"quick_lines"), "buy")
	sim.tick(250)

	# 500 ms at the old speed is half a widget, and 250 ms at twice the speed
	# is the other half.
	assert_eq(sim.factory(factory).output_bay_count, 1)
	sim.tick(2000)
	assert_eq(sim.factory(factory).output_bay_count, 5, "one widget each 500 ms")


func test_a_starting_money_upgrade_adds_its_money_at_once() -> void:
	var sim := _sim(3)
	var before := sim.money()

	_ok(sim.buy_prestige_upgrade(&"seed_money"), "buy")

	assert_true(sim.money().equals(before.add(BigNumber.from_int(ContentFixture.SEED_MONEY))),
		"money is %s" % sim.money())


func test_a_prestige_keeps_the_upgrades_and_the_prisms_left() -> void:
	var sim := _sim(3)
	_ok(sim.buy_prestige_upgrade(&"quick_lines"), "buy")

	_ok(sim.prestige(), "prestige")

	assert_true(sim.prestige_upgrade(&"quick_lines").owned)
	assert_false(sim.prestige_upgrade(&"seed_money").owned)
	assert_eq(sim.prisms().owned, 2)


func test_upgrades_have_their_effect_in_all_later_runs() -> void:
	var sim := _sim(4)
	_ok(sim.buy_prestige_upgrade(&"quick_lines"), "buy speed")
	_ok(sim.buy_prestige_upgrade(&"seed_money"), "buy money")

	for run in 2:
		_ok(sim.prestige(), "prestige %d" % run)
		assert_true(sim.money().equals(BigNumber.from_int(1000 + ContentFixture.SEED_MONEY)),
			"run %d starts with the bonus, money is %s" % [run, sim.money()])
		var factory: int = _ok(sim.build_factory(&"red"), "build")
		sim.tick(500)
		assert_eq(sim.factory(factory).output_bay_count, 1, "run %d makes one widget each 500 ms" % run)


func test_an_upgrade_unlocks_a_color_at_once_and_in_later_runs() -> void:
	var sim := _sim(3)
	var locked := sim.build_factory(&"white")
	assert_eq(locked.reason, CommandResult.Reason.COLOR_LOCKED)
	assert_eq(locked.message, "White needs a prestige upgrade first: White light.")
	assert_false(sim.buildable_factory_colors().has(&"white"))

	_ok(sim.buy_prestige_upgrade(&"white_light"), "buy")

	assert_true(sim.is_color_unlocked(&"white"))
	_ok(sim.build_factory(&"white"), "build white")
	_ok(sim.prestige(), "prestige")
	assert_true(sim.buildable_factory_colors().has(&"white"), "white stays unlocked in the next run")
	_ok(sim.build_factory(&"white"), "build white in the next run")


func test_production_speed_bonuses_multiply() -> void:
	var upgrades := {"upgrades": [
		{"id": "a", "name": "A", "price": 1, "bonuses": {"production_speed": 2.0}},
		{"id": "b", "name": "B", "price": 1, "bonuses": {"production_speed": 1.5}},
		{"id": "white_light", "name": "White light", "price": 1, "unlocks": {"colors": ["white"]}},
	]}
	var sim := _sim(2, _content(upgrades))
	_ok(sim.buy_prestige_upgrade(&"a"), "buy a")
	_ok(sim.buy_prestige_upgrade(&"b"), "buy b")
	var factory: int = _ok(sim.build_factory(&"red"), "build")

	# Three times as fast: one widget each 333 ms, to the nearest millisecond.
	sim.tick(332)
	assert_eq(sim.factory(factory).output_bay_count, 0)
	sim.tick(1)
	assert_eq(sim.factory(factory).output_bay_count, 1)


func test_the_order_of_purchase_does_not_change_the_state() -> void:
	var a := _sim(3)
	var b := _sim(3)

	_ok(a.buy_prestige_upgrade(&"quick_lines"), "a speed")
	_ok(a.buy_prestige_upgrade(&"seed_money"), "a money")
	_ok(b.buy_prestige_upgrade(&"seed_money"), "b money")
	_ok(b.buy_prestige_upgrade(&"quick_lines"), "b speed")

	assert_eq(a.snapshot(), b.snapshot())
	assert_eq(a.snapshot().prestige_upgrades, ["quick_lines", "seed_money"], "in content order")


func test_the_query_lists_each_upgrade_with_its_price_and_effects() -> void:
	var sim := _sim(3)
	_ok(sim.buy_prestige_upgrade(&"seed_money"), "buy")

	var views := sim.prestige_upgrades()

	assert_eq(views.map(func(v: PrestigeUpgradeView) -> StringName: return v.id),
		[&"quick_lines", &"seed_money", &"white_light"])
	assert_eq(views.map(func(v: PrestigeUpgradeView) -> int: return v.price),
		[ContentFixture.QUICK_LINES_PRICE, ContentFixture.SEED_MONEY_PRICE, 1])
	assert_eq(views.map(func(v: PrestigeUpgradeView) -> bool: return v.owned), [false, true, false])
	assert_eq(views[0].production_speed, 2.0)
	assert_true(views[0].starting_money.is_zero())
	assert_eq(views[1].production_speed, 1.0)
	assert_true(views[1].starting_money.equals(BigNumber.from_int(ContentFixture.SEED_MONEY)))
	assert_eq(views[2].unlock_colors, [&"white"] as Array[StringName])
	assert_null(sim.prestige_upgrade(&"magic"))


func test_changing_a_view_does_not_change_the_game() -> void:
	var sim := _sim(3)
	var view := sim.prestige_upgrade(&"white_light")

	view.owned = true
	view.unlock_colors.append(&"red")

	assert_false(sim.prestige_upgrade(&"white_light").owned)
	assert_false(sim.is_color_unlocked(&"white"))
	assert_eq(sim.prestige_upgrade(&"white_light").unlock_colors, [&"white"] as Array[StringName])
