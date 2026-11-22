class_name LayoutGame
extends RefCounted
## A game that fills the screen as much as a real game can, for the layout
## tests: all colors unlocked, factories and warehouses of colors with long
## names, links of each kind with shipments in transit, vehicles to upgrade,
## automatic transport, a split, a sell threshold that holds, research in
## progress, an active demand event, generated markets, owned prestige
## upgrades, large money, and an active guided start.

## The money of the game: a large number, which has the longest format.
const MONEY := 123_456_789_012_345_678


## The save text of the game, for [method SaveCodec.decode], with the state
## for [param saved_at_unix_ms].
static func save_text(saved_at_unix_ms: int) -> String:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var game := _rich_state(content, Simulation.new(content, 5), saved_at_unix_ms)
	_check(game.build_lab(), "a lab")
	game.build_factory(&"red")
	game.build_factory(&"yellow")
	game.build_factory(&"blue")
	game.build_factory(&"yellow_orange_tint")
	game.build_factory(&"blue_purple_shade")
	game.build_factory(&"yellow_orange")
	_check(game.build_warehouse(&"yellow_orange_tint"), "a warehouse")
	_check(game.build_warehouse(&"red"), "a red warehouse")
	# Link 1 has a cart, which can upgrade after the tiers below.
	_check(game.make_link(1, &"millbrook"), "red to Millbrook")
	_check(game.buy_transport_tier(), "trucks")
	_check(game.make_link(1, &"ashford"), "red to Ashford")
	_check(game.link_factory_to_warehouse(4, 1), "the tint to its warehouse")
	_check(game.link_warehouse_to_market(1, &"millbrook"), "the warehouse to Millbrook")
	_check(game.link_factory_to_warehouse(1, 2), "red to its warehouse")
	_check(game.link_warehouse_to_lab(2, 1), "the red warehouse to the lab")
	_check(game.make_factory_link(2, 6), "yellow to yellow-orange")
	for id: int in [1, 2, 3, 4]:
		_check(game.buy_automatic_transport(id), "automatic transport for link %d" % id)
	_check(game.set_split({1: 70, 2: 30}), "a split of red")
	_check(game.set_sell_threshold(1, 1000), "a sell threshold that holds")
	_check(game.select_research(&"market_surveys"), "research")
	game.tick(300_000)
	_check(game.start_shipment(7), "a shipment by hand")
	game.tick(1_000)
	for i in 2:
		_check(game.buy_transport_tier(), "a transport tier")
	var save: Dictionary = JSON.parse_string(SaveCodec.encode(game, saved_at_unix_ms))
	save.state.guided_start = "start_shipment"
	return JSON.stringify(save)


## A new game with large money and prisms, all research complete, and all
## prestige upgrades owned, so that all colors are unlocked.
static func _rich_state(content: Content, game: Simulation, saved_at_unix_ms: int) -> Simulation:
	var save: Dictionary = JSON.parse_string(SaveCodec.encode(game, saved_at_unix_ms))
	save.state.money = BigNumber.from_int(MONEY).to_data()
	save.state.prisms = 12_345
	save.state.prisms_bought = 12_345
	var research: Array = []
	# Market surveys and the research that needs it stay to do, so that the
	# research section shows research of each status.
	for view in game.research():
		if view.id not in [&"market_surveys", &"trend_analysis", &"consumer_panels"]:
			research.append(String(view.id))
	save.state.completed_research = research
	var upgrades: Array = []
	for view in game.prestige_upgrades():
		upgrades.append(String(view.id))
	save.state.prestige_upgrades = upgrades
	var result := SaveCodec.decode(content, JSON.stringify(save))
	assert(result.ok, result.message)
	return result.simulation


static func _check(result: CommandResult, what: String) -> void:
	if not result.ok:
		push_error("The layout game could not make %s: %s" % [what, result.message])
