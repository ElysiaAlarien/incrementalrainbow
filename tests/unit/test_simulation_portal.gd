extends GutTest
## The portal: the last transport tier, which reaches a market at any
## remoteness. The fixture markets are millbrook (remoteness 0), farpoint (2),
## and lastport (4), then generated markets from remoteness 5. Carts reach 0,
## trucks 2, trains 4, and then the portal reaches any remoteness. The game
## shows 2 markets still to reach.

const SEED := 21
const SAVED_AT_UNIX_MS := 1_700_000_000_000


func _content(with_portal: bool = true) -> Content:
	var colors := ContentFixture.mixed_colors_data()
	return ContentFixture.from_data(ContentFixture.data(colors,
		ContentFixture.balance_data(1000, 10, ContentFixture.demand_overrides().merged(
			{"starting_money": 1000})),
		ContentFixture.generated_markets_data(colors, 2),
		ContentFixture.portal_transport_data() if with_portal else ContentFixture.transport_data()))


## A game with the portal and one red factory.
func _portal_game() -> Simulation:
	var sim := Simulation.new(_content(), SEED)
	for i in 3:
		var result := sim.buy_transport_tier()
		assert_true(result.ok, result.message)
	assert_eq(sim.transport_tier().id, &"portal")
	assert_true(sim.build_factory(&"red").ok)
	return sim


func _ids(sim: Simulation) -> Array:
	return sim.markets().map(func(v: MarketView) -> StringName: return v.id)


func _newest_generated(sim: Simulation) -> MarketView:
	var generated := sim.markets().filter(func(v: MarketView) -> bool:
		return String(v.id).begins_with("generated_"))
	return generated[-1]


## Links factory 1 to the last market that it has no link to yet, and returns
## the new link id.
func _link_to_the_newest_free_market(sim: Simulation) -> int:
	var free := sim.markets().filter(func(v: MarketView) -> bool: return not sim.has_link(1, v.id))
	var result := sim.make_link(1, free[-1].id)
	assert_true(result.ok, result.message)
	return result.value


func test_buying_the_portal_opens_every_market() -> void:
	var sim := _portal_game()

	for view in sim.markets():
		assert_true(view.is_open, "%s is open" % view.id)
	assert_eq(_ids(sim), [&"millbrook", &"farpoint", &"lastport", &"generated_1", &"generated_2"],
		"the markets from trains stay, and 5 markets with no link are enough")
	assert_null(sim.next_transport_tier(), "the portal is the last tier")


func test_before_the_portal_a_generated_market_shows_that_it_needs_the_portal() -> void:
	var sim := Simulation.new(_content(), SEED)
	assert_true(sim.buy_transport_tier().ok)
	assert_true(sim.buy_transport_tier().ok)
	assert_true(sim.build_factory(&"red").ok)

	var view := sim.market(&"generated_1")
	assert_false(view.is_open)
	assert_eq(view.needed_tier, &"portal")
	var result := sim.make_link(1, &"generated_1")
	assert_eq(result.reason, CommandResult.Reason.MARKET_TOO_REMOTE)
	assert_string_contains(result.message, "it needs portals")


func test_with_the_portal_a_link_can_go_to_any_generated_market() -> void:
	var sim := _portal_game()

	for i in 20:
		assert_eq(sim.link(_link_to_the_newest_free_market(sim)).vehicle, &"portal")

	assert_gt(_newest_generated(sim).remoteness, 4 + 15, "links reach ever more remote markets")


func test_with_the_portal_a_link_to_a_market_makes_the_next_market() -> void:
	var sim := _portal_game()
	for id: StringName in [&"millbrook", &"farpoint", &"lastport"]:
		assert_true(sim.make_link(1, id).ok)
	assert_eq(_ids(sim).size(), 5, "generated_1 and generated_2 have no link")

	assert_true(sim.make_link(1, &"generated_1").ok)

	assert_eq(_ids(sim).size(), 6, "the game always shows 2 markets that no link goes to")
	assert_eq(_ids(sim)[-1], &"generated_3")
	assert_true(sim.market(&"generated_3").is_open)


func test_a_link_from_a_warehouse_also_makes_the_next_market() -> void:
	var sim := _portal_game()
	var warehouse := sim.build_warehouse(&"red")
	assert_true(warehouse.ok, warehouse.message)
	for id: StringName in [&"millbrook", &"farpoint", &"lastport", &"generated_1"]:
		var result := sim.link_warehouse_to_market(warehouse.value, id)
		assert_true(result.ok, result.message)

	assert_eq(_ids(sim)[-1], &"generated_3")


func test_a_link_to_a_factory_makes_no_market() -> void:
	var sim := _portal_game()
	assert_true(sim.build_factory(&"purple").ok)
	var before := _ids(sim)

	var result := sim.make_factory_link(1, 2)
	assert_true(result.ok, result.message)

	assert_eq(_ids(sim), before)


func test_without_a_portal_a_link_makes_no_market() -> void:
	var sim := Simulation.new(_content(false), SEED)
	assert_true(sim.buy_transport_tier().ok)
	assert_true(sim.buy_transport_tier().ok)
	assert_true(sim.build_factory(&"red").ok)
	var before := _ids(sim)

	for id: StringName in [&"millbrook", &"farpoint", &"lastport"]:
		assert_true(sim.make_link(1, id).ok)

	assert_eq(_ids(sim), before, "with a limited tier, only closed markets count")


func test_save_then_load_keeps_the_portal_and_its_links() -> void:
	var sim := _portal_game()
	for i in 8:
		_link_to_the_newest_free_market(sim)
	assert_gt(_ids(sim).size(), 5, "the links made generated markets")

	var result := SaveCodec.decode(_content(), SaveCodec.encode(sim, SAVED_AT_UNIX_MS))

	assert_true(result.ok, result.message)
	var loaded := result.simulation
	assert_eq(loaded.transport_tier().id, &"portal")
	assert_eq(_ids(loaded), _ids(sim), "the load makes no more markets")
	assert_eq(loaded.links().map(func(v: LinkView) -> Array: return [v.id, v.vehicle]),
		sim.links().map(func(v: LinkView) -> Array: return [v.id, v.vehicle]))
	for view in loaded.markets():
		assert_true(view.is_open, "%s is open" % view.id)
