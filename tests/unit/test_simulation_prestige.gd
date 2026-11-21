extends GutTest
## Prestige: the player ends a run and starts a fresh one. A prestige keeps
## prisms and the prism price, and clears the run (see ADR-0012).

const SEED := 19
## Each snapshot key, and the name in the prestige preview that tells the
## player about it. Null for a key that the player does not see. When a
## feature adds a snapshot key, add it here with its name, and add the name to
## the keeps or the clears of the core.
const PREVIEW_NAME_OF_KEY := {
	"time_ms": null,
	"rng": null,
	"money": "Money",
	"next_factory_id": "Factories",
	"factories": "Factories",
	"next_link_id": "Links, with their vehicles and shipments",
	"links": "Links, with their vehicles and shipments",
	"next_shipment_id": "Links, with their vehicles and shipments",
	"drift_key": "Demand and saturation",
	"saturation": "Demand and saturation",
	"demand_events": "Demand and saturation",
	"next_demand_event_ms": "Demand and saturation",
	"prisms": "Prisms",
	"prisms_bought": "Prism price",
	"markets": "Community investments and capacity used in each market",
	"next_warehouse_id": "Warehouses and the widgets in them",
	"warehouses": "Warehouses and the widgets in them",
}
## The snapshot keys that come from the random number generator, so a fresh
## run has other values than a new game with another seed.
const RANDOM_KEYS: Array[String] = ["rng", "drift_key"]


## Content with mixed colors, drift, and saturation, and 1000 money at the
## start. Prisms cost 20, then 40, then 80.
func _content() -> Content:
	return ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(700, 6, ContentFixture.demand_overrides().merged(
			{"starting_money": 1000}))))


## A run with factories, links to a market and to a mixed factory, shipments
## on their way, automatic transport, sales that saturate a color, and two
## prisms.
func _played_run() -> Simulation:
	var sim := Simulation.new(_content(), SEED)
	assert_true(sim.build_factory(&"red").ok)
	assert_true(sim.build_factory(&"yellow").ok)
	assert_true(sim.build_factory(&"green").ok)
	assert_true(sim.add_production_line(1).ok)
	assert_true(sim.make_link(1, &"millbrook").ok)
	assert_true(sim.make_factory_link(2, 3).ok)
	assert_true(sim.buy_automatic_transport(1).ok)
	sim.tick(3000)
	assert_true(sim.start_shipment(2).ok)
	sim.tick(ContentFixture.TRANSIT_TIME_MS + 100)
	assert_true(sim.buy_prism().ok)
	assert_true(sim.buy_prism().ok)
	assert_true(sim.make_community_investment(&"millbrook", MarketView.Investment.POPULATION).ok)
	assert_true(sim.make_community_investment(&"millbrook", MarketView.Investment.INCOME).ok)
	return sim


## The snapshot keys that a prestige keeps, from the names in the preview.
func _kept_keys(sim: Simulation) -> Array[String]:
	var keys: Array[String] = []
	var keeps := sim.prestige_preview().keeps
	for key: String in PREVIEW_NAME_OF_KEY:
		var entry: Variant = PREVIEW_NAME_OF_KEY[key]
		if entry != null and keeps.has(entry):
			keys.append(key)
	return keys


## [param snapshot] without the keys of [param keys].
func _without(snapshot: Dictionary, keys: Array[String]) -> Dictionary:
	var result := snapshot.duplicate(true)
	for key in keys:
		result.erase(key)
	return result


func test_the_played_run_has_state_to_clear() -> void:
	# The tests below show that a prestige clears only what this run has.
	var sim := _played_run()
	assert_eq(sim.factories().size(), 3)
	assert_eq(sim.links().size(), 2)
	assert_ne(sim.link(1).automatic, LinkView.Automatic.MANUAL, "link 1 has automatic transport")
	assert_gt(sim.link(1).shipments_in_transit.size(), 0, "a shipment on its way to the market")
	assert_lt(sim.market(&"millbrook").demands[&"red"], 1.0, "sales saturate red")
	assert_gt(sim.time_ms(), 0)


func test_a_prestige_with_no_prisms_fails_and_changes_nothing() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.build_factory(&"red")
	sim.tick(1000)
	var before := sim.snapshot()

	var result := sim.prestige()

	assert_false(result.ok)
	assert_eq(result.reason, CommandResult.Reason.NO_PRISMS)
	assert_eq(result.message, "A prestige needs at least one prism. Buy a prism first.")
	assert_eq(sim.snapshot(), before)


func test_a_prestige_with_a_prism_succeeds() -> void:
	var sim := Simulation.new(_content(), SEED)
	sim.buy_prism()

	var result := sim.prestige()

	assert_true(result.ok, result.message)


func test_a_prestige_clears_money_factories_and_links() -> void:
	var sim := _played_run()

	assert_true(sim.prestige().ok)

	assert_true(sim.money().equals(BigNumber.from_int(1000)), "money is the start money, got %s" % sim.money())
	assert_eq(sim.factories().size(), 0)
	assert_eq(sim.links().size(), 0)
	assert_eq(sim.time_ms(), 0, "the time of the run starts again")


func test_after_a_prestige_ids_start_again_as_in_a_new_game() -> void:
	var sim := _played_run()
	sim.prestige()

	assert_eq(sim.build_factory(&"red").value, 1)
	assert_eq(sim.make_link(1, &"millbrook").value, 1)


func test_a_prestige_clears_saturation_and_shipments_on_their_way() -> void:
	var sim := _played_run()

	sim.prestige()

	assert_eq(sim.snapshot().saturation, [], "no color is saturated")
	var money_before := sim.money()
	sim.tick(60_000)
	assert_true(sim.money().equals(money_before), "no old shipment sells in the new run")


func test_a_prestige_clears_community_investments_and_capacity_used() -> void:
	var sim := _played_run()
	sim.tick(ContentFixture.TRANSIT_TIME_MS)
	var before := sim.market(&"millbrook")
	assert_gt(before.capacity_used, 0, "the run sold widgets in this period")
	assert_gt(before.population, ContentFixture.POPULATION, "the run grew the population")

	sim.prestige()

	var market := sim.market(&"millbrook")
	assert_eq([market.population, market.income, market.capacity_used, market.capacity_in_transit],
		[ContentFixture.POPULATION, ContentFixture.INCOME, 0, 0])
	assert_eq(market.investment_cost(MarketView.Investment.POPULATION).format(),
		str(ContentFixture.INVESTMENT_COST), "investment costs start again")


func test_a_prestige_keeps_prisms_and_the_prism_price() -> void:
	var sim := _played_run()
	var before := sim.prisms()

	sim.prestige()

	var after := sim.prisms()
	assert_eq(after.owned, 2)
	assert_eq(after.total_bought, before.total_bought)
	assert_true(after.next_price.equals(before.next_price), "the price is %s, not %s" % [
		after.next_price, before.next_price])


func test_the_prism_price_does_not_go_down_in_the_next_run() -> void:
	var sim := _played_run()
	sim.prestige()

	assert_true(sim.buy_prism().ok)

	assert_true(sim.money().equals(BigNumber.from_int(1000 - 80)), "the third prism costs 80, got %s" % sim.money())
	assert_eq(sim.prisms().total_bought, 3)


func test_after_a_prestige_all_state_but_the_kept_set_is_as_in_a_new_game() -> void:
	# This test covers state that later features add: a prestige must clear it
	# unless it is in the keep set.
	var sim := _played_run()

	sim.prestige()

	var new_game := Simulation.new(_content(), SEED)
	var ignored := _kept_keys(sim) + RANDOM_KEYS
	assert_eq(_kept_keys(sim), ["prisms", "prisms_bought"] as Array[String])
	assert_eq(_without(sim.snapshot(), ignored), _without(new_game.snapshot(), ignored))


func test_the_preview_names_each_part_of_the_state() -> void:
	# A feature that adds state must also tell the player if a prestige keeps
	# or clears it.
	var sim := _played_run()
	var preview := sim.prestige_preview()

	var keys := sim.snapshot().keys()
	keys.sort()
	var named := PREVIEW_NAME_OF_KEY.keys()
	named.sort()
	assert_eq(keys, named, "each snapshot key has a name in PREVIEW_NAME_OF_KEY")
	var entries := {}
	for key: String in PREVIEW_NAME_OF_KEY:
		var entry: Variant = PREVIEW_NAME_OF_KEY[key]
		if entry != null:
			entries[entry] = true
			assert_true(preview.keeps.has(entry) or preview.clears.has(entry), "the preview names %s" % entry)
	for entry in preview.keeps + preview.clears:
		assert_true(entries.has(entry), "%s names state" % entry)


func test_the_same_run_and_prestige_give_the_same_new_run() -> void:
	var a := _played_run()
	var b := _played_run()

	a.prestige()
	b.prestige()
	for sim: Simulation in [a, b]:
		sim.build_factory(&"red")
		sim.make_link(1, &"millbrook")
		sim.buy_automatic_transport(1)
		sim.tick(40_000)

	assert_eq(a.snapshot(), b.snapshot())


func test_the_new_run_has_new_random_values() -> void:
	var sim := _played_run()
	var before := sim.snapshot()

	sim.prestige()

	assert_ne(sim.snapshot().drift_key, before.drift_key, "demand drifts in a new way")
	assert_ne(sim.snapshot().rng, before.rng)


func test_a_prestige_can_happen_again_while_prisms_are_kept() -> void:
	var sim := _played_run()
	sim.prestige()

	assert_true(sim.prestige().ok)

	assert_eq(sim.prisms().owned, 2)


func test_the_preview_shows_what_a_prestige_keeps_and_clears() -> void:
	var sim := _played_run()

	var view := sim.prestige_preview()

	assert_true(view.allowed)
	assert_eq(view.message, "")
	assert_eq(view.keeps, PackedStringArray(["Prisms", "Prism price"]))
	assert_eq(view.clears, PackedStringArray(["Money", "Factories",
		"Links, with their vehicles and shipments", "Demand and saturation",
		"Community investments and capacity used in each market",
		"Warehouses and the widgets in them"]))


func test_the_preview_with_no_prisms_gives_the_reason() -> void:
	var sim := Simulation.new(_content(), SEED)

	var view := sim.prestige_preview()

	assert_false(view.allowed)
	assert_eq(view.message, sim.prestige().message)
	assert_false(view.keeps.is_empty(), "the preview shows the keep set also when a prestige is not allowed")


func test_changing_the_preview_does_not_change_the_game() -> void:
	var sim := Simulation.new(_content(), SEED)
	var view := sim.prestige_preview()

	view.keeps.append("Money")
	view.clears.clear()
	view.allowed = true

	var again := sim.prestige_preview()
	assert_false(again.allowed)
	assert_false(again.keeps.has("Money"))
	assert_false(again.clears.is_empty())
	assert_false(sim.prestige().ok)
