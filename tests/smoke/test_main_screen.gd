extends GutTest
## Smoke tests: the main screen loads, builds a factory, shows it, and keeps it
## in a save.

const MainScene := preload("res://src/ui/main.tscn")
## A save path of its own, so that tests never touch the player's save.
const SAVE_PATH := "user://test_saves/main_screen.json"


func before_each() -> void:
	for path in [SAVE_PATH, SAVE_PATH + SaveFile.DAMAGED_SUFFIX, SAVE_PATH + SaveFile.TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func after_all() -> void:
	before_each()


func _open_main() -> Control:
	var main: Control = MainScene.instantiate()
	main.save_path = SAVE_PATH
	add_child_autofree(main)
	await wait_process_frames(1)
	return main


## The save that the screen wrote.
func _read_save() -> LoadResult:
	return SaveCodec.decode(Content.load_dir(Content.DEFAULT_DIR), FileAccess.get_file_as_string(SAVE_PATH))


func _rows(main: Control) -> Array[Node]:
	return main.find_children("Factory*", "FactoryRow", true, false)


func test_building_a_factory_shows_it_on_the_screen() -> void:
	var main := await _open_main()

	var button: Button = main.find_child("Build_red", true, false)
	assert_not_null(button, "a build button for red")
	button.pressed.emit()
	main.simulation().tick(60_000)
	await wait_process_frames(1)

	var rows := _rows(main)
	assert_eq(rows.size(), 1)
	var row: FactoryRow = rows[0]
	assert_eq(row.bay_text(), "Output bay: 10 / 10")
	assert_eq(row.status_text(), "Stopped: output bay full")
	assert_false(main.find_child("EmptyLabel", true, false).visible)


## The main screen with one red factory built.
func _main_with_red_factory() -> Control:
	var main := await _open_main()
	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	return main


func _first_row(main: Control) -> FactoryRow:
	return main.find_children("Factory*", "FactoryRow", true, false)[0]


func test_adding_a_production_line_shows_the_new_size_and_money() -> void:
	var main: Control = await _main_with_red_factory()
	var row := _first_row(main)
	assert_eq(row.size_text(), "1 line")
	var money_before: BigNumber = main.simulation().money()
	row.add_line_button().pressed.emit()
	await wait_process_frames(1)

	assert_eq(row.size_text(), "2 lines")
	assert_true(main.simulation().money().is_less_than(money_before), "the line cost money")
	var money_label: Label = main.find_child("MoneyLabel", true, false)
	assert_eq(money_label.text, "Money: %s" % main.simulation().money().format())


func test_adding_a_line_with_too_little_money_shows_the_reason() -> void:
	var main: Control = await _main_with_red_factory()
	var row := _first_row(main)

	# Add lines until the money runs out; the last press fails.
	var message_label: Label = main.find_child("MessageLabel", true, false)
	for i in 1000:
		row.add_line_button().pressed.emit()
		if message_label.visible:
			break

	assert_true(message_label.visible, "a reason is shown")
	assert_string_contains(message_label.text, "costs")


func test_the_game_saves_on_exit_and_loads_on_start() -> void:
	var first := await _open_main()
	first.find_child("Build_red", true, false).pressed.emit()
	first.find_child("MakeLink", true, false).pressed.emit()
	first.simulation().add_production_line(1)
	first.simulation().tick(1_750)
	var saved_snapshot: Dictionary = first.simulation().snapshot()
	remove_child(first)
	first.free()
	var saved := _read_save()
	assert_true(saved.ok, "the exit saved the game: %s" % saved.message)
	assert_eq(saved.simulation.snapshot(), saved_snapshot)

	var second := await _open_main()

	assert_eq(second.simulation().factories()[0].id, 1)
	assert_gte(second.simulation().time_ms(), 1_750)
	var rows := _rows(second)
	assert_eq(rows.size(), 1)
	assert_eq((rows[0] as FactoryRow).bay_text(), "Output bay: 3 / 10")
	assert_eq((rows[0] as FactoryRow).size_text(), "2 lines")
	assert_true(second.simulation().money().equals(saved.simulation.money()))
	assert_eq(second.find_children("Link*", "LinkRow", true, false).size(), 1, "the link is kept")


func test_the_game_saves_at_intervals() -> void:
	var main := await _open_main()
	var autosave: Timer = main.find_child("Autosave", true, false)
	assert_not_null(autosave)
	assert_false(autosave.is_stopped())
	assert_false(autosave.one_shot)
	assert_eq(autosave.wait_time, main.AUTOSAVE_INTERVAL_S)

	main.find_child("Build_blue", true, false).pressed.emit()
	autosave.timeout.emit()

	var result := _read_save()
	assert_true(result.ok, result.message)
	assert_eq(result.simulation.factories().size(), 1)


func test_a_damaged_save_starts_a_new_game_and_keeps_a_copy() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"format\": \"incremental-rainbow-save\", \"vers")
	file.close()

	var main := await _open_main()

	assert_eq(_rows(main).size(), 0, "a new game")
	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "could not load")
	assert_string_contains(message.text, "not valid JSON")
	assert_eq(FileAccess.get_file_as_string(SAVE_PATH + SaveFile.DAMAGED_SUFFIX),
		"{\"format\": \"incremental-rainbow-save\", \"vers", "the damaged save is kept")


func test_a_damaged_save_that_cannot_move_is_not_overwritten() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	# A folder with a file in it at the copy's path makes the move fail.
	var blocker := SAVE_PATH + SaveFile.DAMAGED_SUFFIX
	DirAccess.make_dir_recursive_absolute(blocker)
	FileAccess.open(blocker.path_join("keep"), FileAccess.WRITE).close()

	var main := await _open_main()
	main.write_save()
	remove_child(main)
	main.free()

	assert_eq(FileAccess.get_file_as_string(SAVE_PATH), "not a save", "the damaged save is not overwritten")
	DirAccess.remove_absolute(blocker.path_join("keep"))
	DirAccess.remove_absolute(blocker)
func test_a_factory_can_be_linked_to_a_market_and_ship_for_money() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var money_label: Label = main.find_child("MoneyLabel", true, false)
	assert_eq(money_label.text, "Money: %s" % sim.money().format())
	assert_string_contains(main.find_child("Build_red", true, false).text,
		"(%s)" % sim.factory_build_cost().format())

	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	var factory_choice: OptionButton = main.find_child("NewLinkFactory", true, false)
	var market_choice: OptionButton = main.find_child("NewLinkDestination", true, false)
	assert_eq(factory_choice.get_item_text(factory_choice.selected), "Red factory #1")
	assert_eq(market_choice.get_item_text(market_choice.selected), "Millbrook")
	main.find_child("MakeLink", true, false).pressed.emit()
	await wait_process_frames(1)

	var rows := main.find_children("Link*", "LinkRow", true, false)
	assert_eq(rows.size(), 1)
	var row: LinkRow = rows[0]
	var link := sim.link(row.link_id)
	assert_string_contains(row.text(), "Vehicle: Cart")
	assert_string_contains(row.text(), "Cost: %s" % link.shipment_cost.format())
	assert_string_contains(row.text(), "Transit: %s" % LinkRow.format_seconds(link.transit_time_ms))
	assert_false(main.find_child("LinksEmptyLabel", true, false).visible)

	sim.tick(3000)
	var before_ship := sim.money()
	row.ship_button().pressed.emit()
	await wait_process_frames(1)
	assert_true(sim.money().is_less_than(before_ship), "the shipment cost money")
	assert_string_contains(row.text(), "widgets on the way")

	sim.tick(sim.link(row.link_id).transit_time_ms)
	await wait_process_frames(1)
	assert_true(sim.money().is_greater_than(before_ship), "the sale made money")
	assert_eq(money_label.text, "Money: %s" % sim.money().format())


func test_a_link_can_be_made_automatic_and_shows_its_throughput() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	main.find_child("MakeLink", true, false).pressed.emit()
	await wait_process_frames(1)
	var row: LinkRow = main.find_children("Link*", "LinkRow", true, false)[0]
	assert_string_contains(row.text(), "Manual")
	assert_string_contains(row.text(), "Throughput: 0/min")
	assert_false(row.automate_button().disabled)
	assert_string_contains(row.automate_button().text, "(%s)" % sim.automatic_transport_cost().format())

	sim.tick(3000)
	row.automate_button().pressed.emit()
	await wait_process_frames(2)

	assert_true(sim.link(row.link_id).is_automatic())
	assert_true(row.automate_button().disabled, "a link buys automatic transport once")
	assert_eq(row.automate_button().text, "Automatic")
	assert_string_contains(row.text(), "Automatic: next shipment in")
	assert_string_contains(row.text(), "widgets on the way")
	var shipped := sim.link(row.link_id).widgets_per_minute
	assert_gt(shipped, 0)
	assert_string_contains(row.text(), "Throughput: %d/min" % shipped)


func test_an_automatic_link_with_too_little_money_shows_why() -> void:
	# A save of an automatic link, with less money than a shipment costs.
	var game := Simulation.new(Content.load_dir(Content.DEFAULT_DIR), 5)
	game.build_factory(&"red")
	game.make_link(1, &"millbrook")
	game.buy_automatic_transport(1)
	game.tick(3000)
	var save: Dictionary = JSON.parse_string(SaveCodec.encode(game))
	save.state.money = BigNumber.from_int(1).to_data()
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save))
	file.close()
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var row: LinkRow = main.find_children("Link*", "LinkRow", true, false)[0]

	sim.tick(sim.link(row.link_id).next_automatic_in_ms + 1)
	await wait_process_frames(1)

	assert_eq(sim.link(row.link_id).automatic, LinkView.Automatic.NOT_ENOUGH_MONEY)
	assert_string_contains(row.text(), "Automatic: not enough money")
	assert_eq(sim.link(row.link_id).shipments_in_transit.size(), 0)


func test_a_failed_command_shows_its_reason() -> void:
	var main := await _open_main()
	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	var make_link: Button = main.find_child("MakeLink", true, false)
	make_link.pressed.emit()

	# The factory already has a link to this market.
	make_link.pressed.emit()
	await wait_process_frames(1)

	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "already has a link")


# --- Export and import ----------------------------------------------------------

## Opens the export and import dialog of [param main].
func _open_export_code_dialog(main: Control) -> ExportCodeDialog:
	main.find_child("ExportCodeButton", true, false).pressed.emit()
	await wait_process_frames(1)
	var dialog: ExportCodeDialog = main.find_child("ExportCodeDialog", true, false)
	assert_true(dialog.visible, "the dialog opens")
	return dialog


func _import_code(dialog: ExportCodeDialog, code: String) -> ConfirmationDialog:
	(dialog.find_child("ImportCodeText", true, false) as TextEdit).text = code
	dialog.find_child("ImportCode", true, false).pressed.emit()
	await wait_process_frames(1)
	return dialog.find_child("ImportConfirm", true, false)


func test_the_export_code_imports_after_the_player_confirms() -> void:
	var main: Control = await _main_with_red_factory()
	main.find_child("MakeLink", true, false).pressed.emit()
	var dialog := await _open_export_code_dialog(main)
	var code := (dialog.find_child("ExportCodeText", true, false) as TextEdit).text
	var exported: Dictionary = ExportCode.decode(Content.load_dir(Content.DEFAULT_DIR), code).simulation.snapshot()
	# The game goes on: a second factory that the code does not have.
	main.find_child("Build_blue", true, false).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_rows(main).size(), 2)

	var confirm := await _import_code(dialog, code)
	assert_true(confirm.visible, "the import asks to confirm")
	assert_eq(main.simulation().factories().size(), 2, "the game does not change before the player confirms")
	confirm.confirmed.emit()
	await wait_process_frames(1)

	assert_false(dialog.visible, "the dialog closes")
	assert_eq(main.simulation().factories().size(), 1)
	assert_gte(main.simulation().time_ms(), exported.time_ms)
	assert_eq(_rows(main).size(), 1, "the screen shows the imported game")
	assert_eq(main.find_children("Link*", "LinkRow", true, false).size(), 1)
	assert_eq((main.find_child("NewLinkFactory", true, false) as OptionButton).item_count, 1)
	var saved := _read_save()
	assert_true(saved.ok, saved.message)
	assert_eq(saved.simulation.factories().size(), 1, "the import is saved at once")


func test_a_canceled_import_does_not_change_the_game() -> void:
	var main: Control = await _main_with_red_factory()
	var dialog := await _open_export_code_dialog(main)
	var code := (dialog.find_child("ExportCodeText", true, false) as TextEdit).text
	main.find_child("Build_blue", true, false).pressed.emit()

	var confirm := await _import_code(dialog, code)
	confirm.canceled.emit()
	await wait_process_frames(1)

	assert_eq(main.simulation().factories().size(), 2)
	assert_eq(_rows(main).size(), 2)


func test_a_bad_code_shows_the_reason_and_does_not_change_the_game() -> void:
	var main: Control = await _main_with_red_factory()
	var dialog := await _open_export_code_dialog(main)
	var before: Simulation = main.simulation()

	var confirm := await _import_code(dialog, "IR2.abcd.00000000")

	assert_false(confirm.visible, "a bad code does not ask to confirm")
	var message: Label = dialog.find_child("ImportMessage", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "your game did not change")
	assert_string_contains(message.text, "checksum does not match")
	assert_same(main.simulation(), before, "the game is the same game")
	assert_eq(main.simulation().factories().size(), 1)


# --- Markets ------------------------------------------------------------------

func test_the_screen_shows_the_price_and_demand_of_each_color_in_each_market() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var rows := main.find_children("Market_*", "MarketRow", true, false)
	assert_eq(rows.size(), sim.markets().size())
	var row: MarketRow = rows[0]
	var view := sim.market(row.market_id)
	for color in Content.load_dir(Content.DEFAULT_DIR).colors():
		assert_eq(row.color_text(color.id), "Price %s, demand %s" % [view.price(color.id).format(),
			MarketRow.format_demand(view.demand(color.id))])

	# A sale of red lowers its demand on the screen.
	main.find_child("Build_red", true, false).pressed.emit()
	main.find_child("MakeLink", true, false).pressed.emit()
	sim.tick(10_000)
	sim.start_shipment(1)
	sim.tick(sim.link(1).transit_time_ms)
	await wait_process_frames(1)
	view = sim.market(row.market_id)
	assert_eq(sim.snapshot().saturation.size(), 1, "the sale saturated red")
	assert_eq(row.color_text(&"red"), "Price %s, demand %s" % [view.price(&"red").format(),
		MarketRow.format_demand(view.demand(&"red"))])
	assert_lte(row.get_global_rect().end.x, main.get_viewport_rect().size.x, "the row fits the screen")


func test_the_screen_shows_capacity_population_and_income_of_each_market() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var row: MarketRow = main.find_child("Market_millbrook", true, false)
	var view := sim.market(&"millbrook")
	assert_string_contains(row.stats_text(), "Population: %s" % BigNumber.from_int(view.population).format())
	assert_string_contains(row.stats_text(), "Income: %s" % BigNumber.from_int(view.income).format())
	assert_string_contains(row.stats_text(), "Capacity: 0 of %s used" % BigNumber.from_int(view.capacity).format())
	assert_string_contains(row.stats_text(), "New period in")

	# A shipment on the way uses capacity.
	main.find_child("Build_red", true, false).pressed.emit()
	main.find_child("MakeLink", true, false).pressed.emit()
	sim.tick(5000)
	sim.start_shipment(1)
	await wait_process_frames(1)
	assert_string_contains(row.stats_text(), "on the way")
	assert_lte(row.get_global_rect().end.x, main.get_viewport_rect().size.x, "the row fits the screen")


func test_a_community_investment_grows_the_market_on_the_screen() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var row: MarketRow = main.find_child("Market_millbrook", true, false)
	var before := sim.market(&"millbrook")
	var button := row.invest_button(MarketView.Investment.POPULATION)
	assert_eq(button.text, "Grow population (%s)" % before.population_investment_cost.format())

	button.pressed.emit()
	row.invest_button(MarketView.Investment.INCOME).pressed.emit()
	await wait_process_frames(1)

	var after := sim.market(&"millbrook")
	assert_gt(after.population, before.population)
	assert_gt(after.income, before.income)
	assert_string_contains(row.stats_text(), "Population: %s" % BigNumber.from_int(after.population).format())
	assert_string_contains(row.stats_text(), "Income: %s" % BigNumber.from_int(after.income).format())
	assert_eq(button.text, "Grow population (%s)" % after.population_investment_cost.format())


func test_a_community_investment_with_too_little_money_shows_the_reason() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var button := (main.find_child("Market_millbrook", true, false) as MarketRow).invest_button(
		MarketView.Investment.INCOME)
	while not sim.money().is_less_than(sim.market(&"millbrook").income_investment_cost):
		button.pressed.emit()
	button.pressed.emit()
	await wait_process_frames(1)

	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "A community investment for income in Millbrook costs")


func test_format_demand_shows_a_whole_percent() -> void:
	assert_eq(MarketRow.format_demand(1.0), "100%")
	assert_eq(MarketRow.format_demand(0.874), "87%")
	assert_eq(MarketRow.format_demand(1.296), "130%")


# --- Demand events -------------------------------------------------------------

func _demand_event_rows(main: Control) -> Array[Node]:
	return main.find_children("DemandEvent_*", "DemandEventRow", true, false)


func test_the_screen_shows_the_name_and_colors_of_each_active_demand_event() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var empty_label: Label = main.find_child("DemandEventsEmptyLabel", true, false)
	assert_true(empty_label.visible, "no demand events at the start")

	# Events start a few minutes apart in the game data.
	for i in 60:
		if not sim.demand_events().is_empty():
			break
		sim.tick(10_000)
	assert_false(sim.demand_events().is_empty(), "a demand event started")
	await wait_process_frames(1)

	var views := sim.demand_events()
	var rows := _demand_event_rows(main)
	assert_eq(rows.size(), views.size())
	assert_false(empty_label.visible)
	var row: DemandEventRow = rows[0]
	var view := views[0]
	var color_names := view.colors.map(func(id: StringName) -> String: return content.color(id).name)
	assert_eq(row.text(), "%s: %s: %s. Ends in %s" % [view.name, DemandEventRow.change_text(view).to_lower(),
		", ".join(color_names), LinkRow.format_seconds(view.remaining_ms)])
	for id in view.colors:
		assert_not_null(row.find_child("Color_%s" % id, true, false), "the symbol of %s" % id)
	assert_lte(row.get_global_rect().end.x, main.get_viewport_rect().size.x, "the row fits the screen")

	# After the events end, their rows go away.
	var longest := 0
	for def in content.demand_events():
		longest = maxi(longest, def.duration_ms)
	var old_keys := rows.map(func(r: DemandEventRow) -> String: return r.key)
	sim.tick(longest)
	await wait_process_frames(1)
	var shown := _demand_event_rows(main).map(func(r: DemandEventRow) -> String: return r.key)
	for key: String in old_keys:
		assert_false(shown.has(key), "the row of the ended event %s is gone" % key)
	assert_eq(shown.size(), sim.demand_events().size())


func test_change_text_shows_the_direction_and_size_as_a_percent() -> void:
	var view := DemandEventView.new()
	view.direction = DemandEventDef.Direction.SPIKE
	view.size = 0.5
	assert_eq(DemandEventRow.change_text(view), "Demand up 50%")
	view.direction = DemandEventDef.Direction.CRASH
	view.size = 0.4
	assert_eq(DemandEventRow.change_text(view), "Demand down 40%")


# --- Prisms --------------------------------------------------------------------

func test_buying_a_prism_shows_the_prisms_and_the_next_price() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var label: Label = main.find_child("PrismLabel", true, false)
	var button: Button = main.find_child("BuyPrism", true, false)
	assert_eq(label.text, "Prisms: 0")
	var first_price := sim.prisms().next_price
	assert_eq(button.text, "Buy prism (%s)" % first_price.format())

	button.pressed.emit()
	await wait_process_frames(1)

	assert_eq(sim.prisms().owned, 1)
	assert_eq(label.text, "Prisms: 1")
	assert_true(first_price.is_less_than(sim.prisms().next_price), "the price went up")
	assert_eq(button.text, "Buy prism (%s)" % sim.prisms().next_price.format())


func test_buying_a_prism_with_too_little_money_shows_the_reason() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var button: Button = main.find_child("BuyPrism", true, false)
	while not sim.money().is_less_than(sim.prisms().next_price):
		button.pressed.emit()
	button.pressed.emit()
	await wait_process_frames(1)

	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "A prism costs")


func test_a_prestige_with_no_prisms_shows_the_reason() -> void:
	var main: Control = await _main_with_red_factory()

	main.find_child("PrestigeButton", true, false).pressed.emit()
	await wait_process_frames(1)

	var confirm: ConfirmationDialog = main.find_child("PrestigeConfirm", true, false)
	assert_false(confirm.visible, "there is nothing to confirm")
	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_eq(message.text, main.simulation().prestige_preview().message)
	assert_eq(main.simulation().factories().size(), 1)


## The main screen with one prism, a red factory, and a link from it.
func _main_ready_to_prestige() -> Control:
	var main := await _open_main()
	main.find_child("BuyPrism", true, false).pressed.emit()
	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	main.find_child("MakeLink", true, false).pressed.emit()
	await wait_process_frames(1)
	assert_eq(main.simulation().prisms().owned, 1)
	assert_eq(_rows(main).size(), 1)
	return main


func test_a_prestige_shows_what_it_keeps_and_clears_before_the_player_confirms() -> void:
	var main: Control = await _main_ready_to_prestige()

	main.find_child("PrestigeButton", true, false).pressed.emit()
	await wait_process_frames(1)

	var confirm: ConfirmationDialog = main.find_child("PrestigeConfirm", true, false)
	assert_true(confirm.visible, "the prestige asks to confirm")
	var preview: PrestigeView = main.simulation().prestige_preview()
	for item in preview.keeps + preview.clears:
		assert_string_contains(confirm.dialog_text, item)
	assert_lt(confirm.dialog_text.find("Keeps"), confirm.dialog_text.find(preview.keeps[0]))
	assert_lt(confirm.dialog_text.find("Clears"), confirm.dialog_text.find(preview.clears[0]))
	assert_eq(main.simulation().factories().size(), 1, "the game does not change before the player confirms")
	confirm.canceled.emit()
	await wait_process_frames(1)
	assert_eq(main.simulation().factories().size(), 1, "a canceled prestige changes nothing")


func test_a_confirmed_prestige_starts_a_new_run_and_saves_it() -> void:
	var main: Control = await _main_ready_to_prestige()
	main.find_child("PrestigeButton", true, false).pressed.emit()
	await wait_process_frames(1)
	var confirm: ConfirmationDialog = main.find_child("PrestigeConfirm", true, false)

	confirm.confirmed.emit()
	await wait_process_frames(1)

	var sim: Simulation = main.simulation()
	assert_eq(sim.factories().size(), 0)
	assert_eq(sim.prisms().owned, 1)
	assert_eq(_rows(main).size(), 0, "the screen shows the new run")
	assert_eq(main.find_children("Link*", "LinkRow", true, false).size(), 0)
	assert_eq((main.find_child("NewLinkFactory", true, false) as OptionButton).item_count, 0)
	assert_true(main.find_child("EmptyLabel", true, false).visible)
	assert_eq((main.find_child("PrismLabel", true, false) as Label).text, "Prisms: 1")
	var saved := _read_save()
	assert_true(saved.ok, saved.message)
	assert_eq(saved.simulation.factories().size(), 0, "the prestige is saved at once")
	assert_eq(saved.simulation.prisms().owned, 1)


func test_the_header_fits_the_screen_width() -> void:
	var main := await _open_main()
	var header: Control = main.find_child("Header", true, false)
	assert_lt(header.get_combined_minimum_size().x, 1280.0 - 64.0)


func _card(main: Control, color_id: StringName) -> ColorCard:
	return main.find_child("Color_%s" % color_id, true, false)


func test_each_color_shows_its_symbol_and_recipe() -> void:
	var main := await _open_main()
	var content := Content.load_dir(Content.DEFAULT_DIR)

	for color in content.colors():
		var card := _card(main, color.id)
		assert_not_null(card, "a card for %s" % color.id)
		var symbol: ColorSymbol = card.find_child("Symbol", true, false)
		assert_eq(symbol.symbol, color.symbol)
		assert_false(ColorSymbol.shape_points(color.symbol, Rect2(0, 0, 20, 20)).is_empty(),
			"the screen can draw the %s symbol" % color.symbol)
	assert_eq(_card(main, &"red").recipe_text(), "no inputs")
	assert_eq(_card(main, &"green").recipe_text(), "Yellow + Blue")
	assert_eq(_card(main, &"brown").recipe_text(), "Red + Yellow + Blue")


func test_a_color_that_needs_research_shows_it_instead_of_a_build_button() -> void:
	var main := await _open_main()

	var green := _card(main, &"green")
	assert_false(green.is_locked())
	assert_true(green.build_button().visible)
	var red_orange := _card(main, &"red_orange")
	assert_true(red_orange.is_locked())
	assert_false(red_orange.build_button().visible)


## Selects the item with [param text] in the option button [param name].
func _choose(main: Control, name: String, text: String) -> void:
	var choice: OptionButton = main.find_child(name, true, false)
	for i in choice.item_count:
		if choice.get_item_text(i) == text:
			choice.select(i)
			return
	fail_test("%s has no item %s" % [name, text])


func test_a_mixed_factory_shows_its_input_bays_and_waits_for_input() -> void:
	var main := await _open_main()
	for color in ["yellow", "blue", "green"]:
		_card(main, color).build_button().pressed.emit()
	await wait_process_frames(1)

	_choose(main, "NewLinkFactory", "Blue factory #2")
	_choose(main, "NewLinkDestination", "Green factory #3")
	main.find_child("MakeLink", true, false).pressed.emit()
	await wait_process_frames(1)
	var link_rows := main.find_children("Link*", "LinkRow", true, false)
	assert_eq(link_rows.size(), 1)
	var link_row: LinkRow = link_rows[0]
	assert_string_contains(link_row.text(), "Blue factory #2 to Green factory #3")

	var sim: Simulation = main.simulation()
	sim.tick(4000)
	link_row.ship_button().pressed.emit()
	sim.tick(sim.link(link_row.link_id).transit_time_ms)
	await wait_process_frames(1)

	var green_row: FactoryRow = main.find_child("Factory3", true, false)
	assert_eq(green_row.status_text(), "Waiting for input")
	var bays := green_row.input_bay_texts()
	assert_eq(bays.size(), 2)
	assert_eq(bays[0], "Yellow 0 / 10 (short)")
	assert_string_contains(bays[1], "Blue ")
	assert_false(bays[1].contains("short"), "blue is there")
	var yellow_row: FactoryRow = main.find_child("Factory1", true, false)
	assert_eq(yellow_row.input_bay_texts().size(), 0, "a base factory has no input bays")


func test_a_link_to_a_factory_whose_recipe_does_not_use_the_color_shows_the_reason() -> void:
	var main := await _open_main()
	for color in ["red", "green"]:
		_card(main, color).build_button().pressed.emit()
	await wait_process_frames(1)

	_choose(main, "NewLinkDestination", "Green factory #2")
	main.find_child("MakeLink", true, false).pressed.emit()
	await wait_process_frames(1)

	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "does not use red")
