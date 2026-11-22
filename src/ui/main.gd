extends Control
## The first screen: money, prisms, each color with its recipe and a button to
## build it, factories with their production lines, output bays, and input
## bays, warehouses with their widgets, throughput, and sell thresholds, the
## transport tier with a button to buy the next one, links from factories and warehouses to
## markets, mixed factories, warehouses, and labs, with their vehicles, manual
## shipments, automatic transport, and throughput, labs and research with its
## progress and unlocks, the split of each source with automatic links, the
## active demand events,
## markets with their remoteness, population, income, capacity, community
## investment, and the price and demand of each color, and the prestige
## upgrades with their prices and which the player owns.
##
## The UI holds no game rules. It sends commands to the Simulation, ticks it
## each frame, and shows what the queries return. It loads the save on start,
## and saves at intervals and when the game exits or goes to the background.
## The Export or import button exports the game as a code and imports a code.
## The Prestige button shows what a prestige keeps and clears, and asks the
## player to confirm. A banner shows the step of the guided start, with a
## button to skip it.
##
## When the player returns (the game starts from a save, a code imports, or a
## phone game comes back from the background), the screen applies offline
## progress for the time away with [method Simulation.progress_offline]. It
## does this in parts over many frames, behind a screen that shows how far it
## is, so that a long time away does not stop the game from drawing. Then it
## shows a summary.

## Seconds between saves while the game runs.
const AUTOSAVE_INTERVAL_S := 30.0
## The real time that offline progress can use in each frame.
const CATCH_UP_BUDGET_MS := 12
## The first part of offline progress, in game time. Later parts grow or
## shrink so that each frame uses about [constant CATCH_UP_BUDGET_MS].
const FIRST_CATCH_UP_PART_MS := 1000
## The summary shows only for at least this much time away, so that a quick
## restart or a short switch to another app does not show it.
const SUMMARY_MIN_AWAY_MS := 60_000

## Where the game keeps its save. Set it before the screen enters the tree.
var save_path := SaveFile.DEFAULT_PATH
## The device clock in Unix milliseconds. Tests set it before the screen
## enters the tree.
var clock := func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)

@onready var _color_cards: HFlowContainer = %ColorCards
@onready var _factory_list: VBoxContainer = %FactoryList
@onready var _empty_label: Label = %EmptyLabel
@onready var _new_warehouse_color: OptionButton = %NewWarehouseColor
@onready var _build_warehouse_button: Button = %BuildWarehouse
@onready var _warehouse_locked_label: Label = %WarehouseLockedLabel
@onready var _warehouse_list: VBoxContainer = %WarehouseList
@onready var _warehouses_empty_label: Label = %WarehousesEmptyLabel
@onready var _new_link_source: OptionButton = %NewLinkSource
@onready var _transport_label: Label = %TransportLabel
@onready var _buy_transport_tier_button: Button = %BuyTransportTier
@onready var _new_link_destination: OptionButton = %NewLinkDestination
@onready var _make_link_button: Button = %MakeLink
@onready var _link_list: VBoxContainer = %LinkList
@onready var _links_empty_label: Label = %LinksEmptyLabel
@onready var _build_lab_button: Button = %BuildLab
@onready var _labs_label: Label = %LabsLabel
@onready var _lab_stock_label: Label = %LabStockLabel
@onready var _research_list: VBoxContainer = %ResearchList
@onready var _demand_event_list: VBoxContainer = %DemandEventList
@onready var _demand_events_empty_label: Label = %DemandEventsEmptyLabel
@onready var _split_list: VBoxContainer = %SplitList
@onready var _splits_empty_label: Label = %SplitsEmptyLabel
@onready var _forecast_label: Label = %ForecastLabel
@onready var _market_list: VBoxContainer = %MarketList
@onready var _prestige_upgrade_list: VBoxContainer = %PrestigeUpgradeList
@onready var _money_label: Label = %MoneyLabel
@onready var _prism_label: Label = %PrismLabel
@onready var _buy_prism_button: Button = %BuyPrism
@onready var _message_label: Label = %MessageLabel
@onready var _export_code_button: Button = %ExportCodeButton
@onready var _prestige_button: Button = %PrestigeButton

var _sim: Simulation
var _save_file: SaveFile
## False when a save that could not load is still at the save path, so that a
## save does not destroy it.
var _can_save := true
var _content: Content
var _rows: Dictionary[int, FactoryRow] = {}
var _link_rows: Dictionary[int, LinkRow] = {}
var _warehouse_rows: Dictionary[int, WarehouseRow] = {}
## The row of the split of each source, by a key such as "factory_1".
var _split_rows: Dictionary[String, SplitRow] = {}
var _market_rows: Dictionary[StringName, MarketRow] = {}
## One row for each research in the content. A new run shows them again.
var _research_rows: Dictionary[StringName, ResearchRow] = {}
## One row for each prestige upgrade in the content.
var _prestige_upgrade_rows: Dictionary[StringName, PrestigeUpgradeRow] = {}
## The rows of the active demand events, by [member DemandEventRow.key].
## Events start in order, so the rows are in start order.
var _demand_event_rows: Dictionary[String, DemandEventRow] = {}
var _export_code_dialog: ExportCodeDialog
var _prestige_confirm := ConfirmationDialog.new()
var _cards: Array[ColorCard] = []
## The metadata of each item in [member _new_link_source], in order, as from
## [method _link_source_keys].
var _source_keys: Array = []
## The metadata of each item in [member _new_link_destination], in order, as
## from [method _link_destination_keys].
var _destination_keys: Array = []
## The transport tier when [member _new_link_destination] was last made, which
## sets which markets in it are open.
var _destination_keys_tier: StringName = &""
## Frame time that is not yet a whole millisecond.
var _carry_ms: float = 0.0
## Offline progress that is not applied yet. While it is more than 0, the game
## catches up and the player cannot act, so frame time adds to it.
var _offline_pending_ms: int = 0
## The offline progress applied since the player returned.
var _offline_summary := OfflineSummary.new()
## The game time of the next part of offline progress.
var _catch_up_part_ms := FIRST_CATCH_UP_PART_MS
## The device clock time when a phone game went to the background, or -1.
var _paused_at_unix_ms: int = -1
## True for the first frame after the background.
var _drop_next_frame := false
var _catch_up_screen: CatchUpScreen
var _summary_dialog: OfflineSummaryDialog
var _guided_start_banner: GuidedStartBanner


func _ready() -> void:
	_content = Content.load_dir(Content.DEFAULT_DIR)
	if not _content.errors.is_empty():
		_show_message("The game data has errors:\n" + "\n".join(_content.errors))
		set_process(false)
		return
	_save_file = SaveFile.new(save_path)
	_catch_up_screen = CatchUpScreen.new()
	add_child(_catch_up_screen)
	_summary_dialog = OfflineSummaryDialog.new()
	add_child(_summary_dialog)
	_sim = _load_or_start_game()
	_guided_start_banner = GuidedStartBanner.new()
	_message_label.add_sibling(_guided_start_banner)
	_message_label.get_parent().move_child(_guided_start_banner, _message_label.get_index())
	_guided_start_banner.skip_pressed.connect(func() -> void: _show_result(_sim.skip_guided_start()))
	var autosave := Timer.new()
	autosave.name = "Autosave"
	autosave.wait_time = AUTOSAVE_INTERVAL_S
	autosave.timeout.connect(write_save)
	add_child(autosave)
	autosave.start()
	for color in _content.colors():
		_add_color_card(color)
	for color in _content.colors():
		_new_warehouse_color.add_icon_item(_symbol_icon(color), color.name)
		_new_warehouse_color.set_item_metadata(_new_warehouse_color.item_count - 1, color.id)
	_build_warehouse_button.pressed.connect(_on_build_warehouse_pressed)
	_make_link_button.pressed.connect(_on_make_link_pressed)
	_export_code_dialog = ExportCodeDialog.new(_content)
	_export_code_dialog.import_confirmed.connect(_replace_game)
	add_child(_export_code_dialog)
	_export_code_button.pressed.connect(func() -> void:
		_export_code_dialog.open(_sim, _state_unix_ms()))
	_buy_prism_button.pressed.connect(_on_buy_prism_pressed)
	_prestige_confirm.name = "PrestigeConfirm"
	_prestige_confirm.title = "Prestige?"
	_prestige_confirm.ok_button_text = "Prestige"
	_prestige_confirm.confirmed.connect(_on_prestige_confirmed)
	add_child(_prestige_confirm)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	_buy_transport_tier_button.pressed.connect(func() -> void: _show_result(_sim.buy_transport_tier()))
	_build_lab_button.pressed.connect(func() -> void: _show_result(_sim.build_lab()))
	for view in _sim.research():
		var row := ResearchRow.new(view, _content)
		row.select_pressed.connect(func(id: StringName) -> void: _show_result(_sim.select_research(id)))
		_research_rows[view.id] = row
		_research_list.add_child(row)
	for view in _sim.prestige_upgrades():
		var row := PrestigeUpgradeRow.new(view, _content)
		row.buy_pressed.connect(func(id: StringName) -> void: _show_result(_sim.buy_prestige_upgrade(id)))
		_prestige_upgrade_rows[view.id] = row
		_prestige_upgrade_list.add_child(row)
	_refresh()


func _process(delta: float) -> void:
	if _paused_at_unix_ms >= 0:
		# In the background until NOTIFICATION_APPLICATION_RESUMED. Its time
		# goes to offline progress then, so frames now do not tick.
		return
	if _drop_next_frame:
		# The first frame after the background can have the whole time away.
		_drop_next_frame = false
		delta = 0.0
	_carry_ms += delta * 1000.0
	var whole_ms := int(_carry_ms)
	_carry_ms -= whole_ms
	if _offline_pending_ms > 0:
		_offline_pending_ms += whole_ms
	else:
		_sim.tick(whole_ms)
	if _offline_pending_ms > 0:
		_catch_up()
	_refresh()


func _exit_tree() -> void:
	# The scene tree removes this screen when the game quits by any path.
	write_save()


func _notification(what: int) -> void:
	# A mobile OS can stop a game in the background with no other notice.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		write_save()
		_paused_at_unix_ms = clock.call()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _paused_at_unix_ms >= 0:
		_return_from_background()


## Starts offline progress for the time that a phone game was in the
## background. The game does not tick there, so that time is time away.
func _return_from_background() -> void:
	var away_ms := maxi(clock.call() - _paused_at_unix_ms, 0)
	_paused_at_unix_ms = -1
	_drop_next_frame = true
	_start_offline_progress(away_ms)


## Adds offline progress for [param away_ms] of time away. The core limits it
## to [method Simulation.max_offline_ms], and the summary keeps the rest.
func _start_offline_progress(away_ms: int) -> void:
	if away_ms <= 0:
		return
	if _offline_pending_ms <= 0:
		_offline_summary = OfflineSummary.new()
	var progress_ms := _sim.offline_progress_ms(away_ms)
	_offline_summary.skipped_ms += away_ms - progress_ms
	_offline_pending_ms += progress_ms
	if _offline_pending_ms <= 0:
		_finish_catch_up()
		return
	_catch_up_screen.show_progress(_offline_summary.duration_ms, _offline_pending_ms)


## Applies offline progress in parts until the frame has used its budget. Each
## part's game time adapts to how long the last part took. Ticks of any length
## give the same state, so the parts do not change the result.
func _catch_up() -> void:
	var begin_ms := Time.get_ticks_msec()
	var applied := OfflineSummary.new()
	while _offline_pending_ms > 0:
		var part_ms := mini(_catch_up_part_ms, _offline_pending_ms)
		var part_begin_ms := Time.get_ticks_msec()
		applied.add(_sim.progress_offline(part_ms))
		_offline_pending_ms -= part_ms
		var took_ms := Time.get_ticks_msec() - part_begin_ms
		if took_ms * 4 < CATCH_UP_BUDGET_MS:
			_catch_up_part_ms *= 2
		elif took_ms > CATCH_UP_BUDGET_MS:
			@warning_ignore("integer_division")
			_catch_up_part_ms = maxi(_catch_up_part_ms / 2, 1)
		if Time.get_ticks_msec() - begin_ms >= CATCH_UP_BUDGET_MS:
			break
	_offline_summary.add(applied)
	if _offline_pending_ms > 0:
		_catch_up_screen.show_progress(_offline_summary.duration_ms, _offline_pending_ms)
		return
	_finish_catch_up()


## Hides the catch-up screen and shows the summary of the time away.
func _finish_catch_up() -> void:
	_catch_up_screen.hide()
	if _offline_summary.duration_ms + _offline_summary.skipped_ms >= SUMMARY_MIN_AWAY_MS:
		_summary_dialog.show_summary(_offline_summary, _sim.max_offline_ms())
	_offline_summary = OfflineSummary.new()


## The device clock time that the state of the game is for: now, less the
## offline progress that is not applied yet. A save keeps it, so that a game
## that closes while it catches up loses no time away.
func _state_unix_ms() -> int:
	return clock.call() - _offline_pending_ms


## Writes the current game to the device.
func write_save() -> void:
	if _sim == null or not _can_save:
		return
	var error := _save_file.write(SaveCodec.encode(_sim, _state_unix_ms()))
	if error != OK:
		push_error("Could not save the game to %s: %s" % [_save_file.path, error_string(error)])
		_show_message("The game could not save: %s." % error_string(error))


## The simulation behind this screen. For smoke tests.
func simulation() -> Simulation:
	return _sim


## Loads the save, or starts a new game when there is no save. A save that
## cannot load is kept in a separate file, so that the next save does not
## destroy it.
func _load_or_start_game() -> Simulation:
	if _save_file.exists():
		var result := SaveCodec.decode(_content, _save_file.read())
		if result.ok:
			_sim = result.simulation
			_start_offline_progress(result.time_away_ms(clock.call()))
			return _sim
		var kept_path := _save_file.keep_damaged()
		var kept_text := "A copy of it is at %s." % ProjectSettings.globalize_path(kept_path)
		if kept_path.is_empty():
			_can_save = false
			kept_text = "The game could not move it, so this game will not save. Your save stays at %s." % \
				ProjectSettings.globalize_path(_save_file.path)
		push_warning("The save did not load: %s" % result.message)
		_show_message("Your save could not load, so a new game started. %s\n%s" % [kept_text, result.message])
	return Simulation.new(_content, randi())


## Replaces the game with the game of [param imported], from an imported code,
## and saves it at once. Offline progress runs from the time of the code.
func _replace_game(imported: LoadResult) -> void:
	_sim = imported.simulation
	_offline_pending_ms = 0
	_offline_summary = OfflineSummary.new()
	_catch_up_screen.hide()
	_start_offline_progress(imported.time_away_ms(clock.call()))
	_show_replaced_run()


## Shows the run of the game after an import or a prestige replaced the last
## run. It removes the rows of the last run, and saves the game at once. The
## market rows go too, because each run has its own generated markets.
func _show_replaced_run() -> void:
	for row: Node in _rows.values() + _link_rows.values() + _warehouse_rows.values() \
			+ _split_rows.values() + _market_rows.values():
		row.get_parent().remove_child(row)
		row.queue_free()
	_market_rows.clear()
	_rows.clear()
	_link_rows.clear()
	_warehouse_rows.clear()
	_split_rows.clear()
	_new_link_source.clear()
	_new_link_destination.clear()
	_source_keys = []
	_destination_keys = []
	_show_message("")
	write_save()
	_refresh()


func _add_color_card(color: ColorDef) -> void:
	var card := ColorCard.new(color, _content)
	card.build_pressed.connect(_on_build_pressed)
	_color_cards.add_child(card)
	_cards.append(card)


func _on_build_pressed(color_id: StringName) -> void:
	_show_result(_sim.build_factory(color_id))


func _on_build_warehouse_pressed() -> void:
	var index := _new_warehouse_color.selected
	if index >= 0:
		_show_result(_sim.build_warehouse(_new_warehouse_color.get_item_metadata(index)))


## Sends the link command for the kinds of the chosen source and destination.
func _on_make_link_pressed() -> void:
	var source_index := _new_link_source.selected
	var destination_index := _new_link_destination.selected
	if source_index < 0 or destination_index < 0:
		_show_message("Build a factory first.")
		return
	var source: Array = _new_link_source.get_item_metadata(source_index)
	var destination: Array = _new_link_destination.get_item_metadata(destination_index)
	match [source[0], destination[0]]:
		[&"factory", &"market"]:
			_show_result(_sim.make_link(source[1], destination[1]))
		[&"factory", &"factory"]:
			_show_result(_sim.make_factory_link(source[1], destination[1]))
		[&"factory", &"warehouse"]:
			_show_result(_sim.link_factory_to_warehouse(source[1], destination[1]))
		[&"warehouse", &"market"]:
			_show_result(_sim.link_warehouse_to_market(source[1], destination[1]))
		[&"warehouse", &"factory"]:
			_show_result(_sim.link_warehouse_to_factory(source[1], destination[1]))
		[&"factory", &"lab"]:
			_show_result(_sim.make_lab_link(source[1], destination[1]))
		[&"warehouse", &"lab"]:
			_show_result(_sim.link_warehouse_to_lab(source[1], destination[1]))
		_:
			_show_message("A warehouse cannot link to another warehouse. Link it to a market, a mixed factory, or a lab.")


func _on_buy_prism_pressed() -> void:
	_show_result(_sim.buy_prism())


## Shows what a prestige keeps and clears and asks the player to confirm, or
## shows why a prestige is not allowed now.
func _on_prestige_pressed() -> void:
	var preview := _sim.prestige_preview()
	if not preview.allowed:
		_show_message(preview.message)
		return
	_prestige_confirm.dialog_text = "A prestige ends this run and starts a fresh one.\n\nKeeps:\n%s\n\nClears:\n%s" % [
		_bullets(preview.keeps), _bullets(preview.clears)]
	_prestige_confirm.popup_centered()


func _on_prestige_confirmed() -> void:
	var result := _sim.prestige()
	if result.ok:
		_show_replaced_run()
	else:
		_show_result(result)


func _bullets(items: PackedStringArray) -> String:
	return "\n".join(Array(items).map(func(item: String) -> String: return "  • " + item))


func _on_ship_pressed(link_id: int) -> void:
	_show_result(_sim.start_shipment(link_id))


func _on_automate_pressed(link_id: int) -> void:
	_show_result(_sim.buy_automatic_transport(link_id))


func _on_invest_pressed(market_id: StringName, goal: MarketView.Investment) -> void:
	_show_result(_sim.make_community_investment(market_id, goal))


func _on_upgrade_vehicle_pressed(link_id: int) -> void:
	_show_result(_sim.upgrade_vehicle(link_id))

func _on_set_split_pressed(shares: Dictionary) -> void:
	_show_result(_sim.set_split(shares))


func _on_clear_split_pressed(link_id: int) -> void:
	_show_result(_sim.clear_split(link_id))


func _on_set_sell_threshold_pressed(warehouse_id: int, percent: int) -> void:
	_show_result(_sim.set_sell_threshold(warehouse_id, percent))


func _on_clear_sell_threshold_pressed(warehouse_id: int) -> void:
	_show_result(_sim.clear_sell_threshold(warehouse_id))


func _show_result(result: CommandResult) -> void:
	_show_message("" if result.ok else result.message)
	_refresh()


func _on_add_line_requested(factory_id: int) -> void:
	_show_result(_sim.add_production_line(factory_id))


func _refresh() -> void:
	_guided_start_banner.show_state(_sim.guided_start())
	_money_label.text = "Money: %s" % _sim.money().format()
	var prisms := _sim.prisms()
	_prism_label.text = "Prisms: %s" % BigNumber.from_int(prisms.owned).format()
	_buy_prism_button.text = "Buy prism (%s)" % prisms.next_price.format()
	var cost := _sim.factory_build_cost()
	for card in _cards:
		card.show_state(_sim.is_color_unlocked(card.color_id), cost)

	for view in _sim.factories():
		var row: FactoryRow = _rows.get(view.id)
		if row == null:
			row = _add_factory_row(view)
		row.show_state(view)
	_empty_label.visible = _rows.is_empty()
	_refresh_warehouses()
	_refresh_transport()
	_refresh_new_link_choices()

	var automatic_cost := _sim.automatic_transport_cost()
	var tier := _sim.transport_tier()
	var links := _sim.links()
	for view in links:
		var link_row: LinkRow = _link_rows.get(view.id)
		if link_row == null:
			link_row = _add_link_row(view)
		link_row.show_state(view, automatic_cost, _content.transport_tier(view.vehicle), tier)
	_links_empty_label.visible = _link_rows.is_empty()
	_refresh_splits(links)
	_refresh_research()

	_refresh_demand_events()

	var forecast := _sim.forecast(_sim.forecast_horizon_ms())
	_forecast_label.text = MarketRow.forecast_text(forecast)
	for view in _sim.markets():
		var market_row: MarketRow = _market_rows.get(view.id)
		if market_row == null:
			market_row = MarketRow.new(view, _content.colors())
			market_row.invest_pressed.connect(_on_invest_pressed)
			_market_rows[view.id] = market_row
			_market_list.add_child(market_row)
		market_row.show_state(view, _needed_tier_plural(view), forecast)

	for view in _sim.prestige_upgrades():
		_prestige_upgrade_rows[view.id].show_state(view)


## The plural name of the transport tier that [param view] needs, such as
## "Trucks", or "" when no tier reaches it.
func _needed_tier_plural(view: MarketView) -> String:
	var tier := _content.transport_tier(view.needed_tier)
	return "" if tier == null else tier.plural_name


func _refresh_research() -> void:
	_build_lab_button.text = "Build lab (%s)" % _sim.lab_build_cost().format()
	var labs := _sim.labs()
	_labs_label.text = "Labs: %s" % ("none" if labs.is_empty() else BigNumber.from_int(labs.size()).format())
	var stock := _sim.lab_stock()
	var parts := PackedStringArray()
	for color in stock:
		parts.append("%s %s" % [_content.color(color).name, BigNumber.from_int(stock[color]).format()])
	_lab_stock_label.text = "Lab stock: %s" % ("empty" if parts.is_empty() else ", ".join(parts))
	_lab_stock_label.tooltip_text = "Widgets that arrived at a lab when the selected research did not need them. They pay for the next research that needs them."
	for view in _sim.research():
		_research_rows[view.id].show_state(view)


func _refresh_transport() -> void:
	var tier := _sim.transport_tier()
	_transport_label.text = "Transport tier: %s, reaches %s" % [tier.name,
		"any distance" if tier.reaches_any_distance else "remoteness %d" % tier.max_remoteness]
	var next := _sim.next_transport_tier()
	_buy_transport_tier_button.disabled = next == null
	_buy_transport_tier_button.text = "Highest tier" if next == null else "Buy %s (%s)" % [
		next.plural_name.to_lower(), next.price.format()]


## Shows a row for each active demand event: a new row when an event starts,
## and no row after it ends.
func _refresh_demand_events() -> void:
	var views := _sim.demand_events()
	var active := {}
	for view in views:
		active[DemandEventRow.key_of(view)] = true
	for key: String in _demand_event_rows.keys():
		if not active.has(key):
			var old := _demand_event_rows[key]
			_demand_event_list.remove_child(old)
			old.queue_free()
			_demand_event_rows.erase(key)
	for view in views:
		var key := DemandEventRow.key_of(view)
		var row: DemandEventRow = _demand_event_rows.get(key)
		if row == null:
			row = DemandEventRow.new(view, _content)
			_demand_event_rows[key] = row
			_demand_event_list.add_child(row)
		row.show_state(view)
	_demand_events_empty_label.visible = _demand_event_rows.is_empty()


func _refresh_warehouses() -> void:
	var unlocked := _sim.is_warehouse_unlocked()
	_new_warehouse_color.visible = unlocked
	_build_warehouse_button.visible = unlocked
	_build_warehouse_button.text = "Build warehouse (%s)" % _sim.warehouse_build_cost().format()
	_warehouse_locked_label.visible = not unlocked
	_warehouse_locked_label.text = "Warehouses unlock when you have %d factories." % \
		_content.warehouse_balance.unlock_factory_count
	for view in _sim.warehouses():
		var row: WarehouseRow = _warehouse_rows.get(view.id)
		if row == null:
			row = WarehouseRow.new(view.id, _content.color(view.color))
			row.set_threshold_pressed.connect(_on_set_sell_threshold_pressed)
			row.clear_threshold_pressed.connect(_on_clear_sell_threshold_pressed)
			_warehouse_rows[view.id] = row
			_warehouse_list.add_child(row)
		var held_names := PackedStringArray()
		for market_id in view.held_market_ids:
			held_names.append(_sim.market(market_id).name)
		row.show_state(view, held_names)
	_warehouses_empty_label.visible = _warehouse_rows.is_empty()


func _add_factory_row(view: FactoryView) -> FactoryRow:
	var row := FactoryRow.new(view.id, _content.color(view.color), _content)
	row.add_line_requested.connect(_on_add_line_requested)
	_rows[view.id] = row
	_factory_list.add_child(row)
	return row


## Keeps the source and destination choices for a new link in step with the
## simulation. Each choice has a key: [code][kind, id][/code], where the kind
## is &"factory", &"warehouse", &"market", or &"lab". The sources are the
## factories, then the warehouses. The destinations are the markets, then the
## mixed factories, then the warehouses, then the labs. When a list changes, it is made again with
## the same place selected.
func _refresh_new_link_choices() -> void:
	var factories := _sim.factories()
	var warehouses := _sim.warehouses()
	_source_keys = _refresh_choice(_new_link_source, _source_keys, _link_source_keys(factories, warehouses))
	# A new tier opens markets, so the destinations change even when their keys
	# do not.
	if _sim.transport_tier().id != _destination_keys_tier:
		_destination_keys = []
		_destination_keys_tier = _sim.transport_tier().id
	_destination_keys = _refresh_choice(_new_link_destination, _destination_keys,
		_link_destination_keys(factories, warehouses))


## Fills [param choice] with an item for each of [param keys] when they are not
## [param old_keys], and keeps the selected key. Returns [param keys]. A closed
## market stays in the list, disabled, with the transport tier it needs.
func _refresh_choice(choice: OptionButton, old_keys: Array, keys: Array) -> Array:
	if keys == old_keys:
		return keys
	var selected: Variant = null
	if choice.selected >= 0:
		selected = choice.get_item_metadata(choice.selected)
	choice.clear()
	for i in keys.size():
		var key: Array = keys[i]
		match key[0]:
			&"factory":
				var view := _sim.factory(key[1])
				choice.add_icon_item(_symbol_icon(_content.color(view.color)), _factory_name(view))
			&"warehouse":
				var view := _sim.warehouse(key[1])
				choice.add_icon_item(_symbol_icon(_content.color(view.color)), _warehouse_name(view))
			&"lab":
				choice.add_item(_lab_name(key[1]))
			_:
				var market := _sim.market(key[1])
				if market.is_open:
					choice.add_item(market.name)
				else:
					var plural := _needed_tier_plural(market)
					choice.add_item("%s (%s)" % [market.name,
						"no tier reaches it yet" if plural.is_empty() else "needs %s" % plural.to_lower()])
					choice.set_item_disabled(i, true)
		choice.set_item_metadata(i, key)
	var keep := keys.find(selected)
	choice.select(keep if keep >= 0 else (0 if not keys.is_empty() else -1))
	return keys


## The places a new link can start: each factory, then each warehouse.
func _link_source_keys(factories: Array[FactoryView], warehouses: Array[WarehouseView]) -> Array:
	var keys: Array = []
	for view in factories:
		keys.append([&"factory", view.id])
	for view in warehouses:
		keys.append([&"warehouse", view.id])
	return keys


## The places a new link can go: each market, then each mixed factory, then
## each warehouse, then each lab.
func _link_destination_keys(factories: Array[FactoryView], warehouses: Array[WarehouseView]) -> Array:
	var keys: Array = []
	for market in _sim.markets():
		keys.append([&"market", market.id])
	for view in factories:
		if not view.input_bays.is_empty():
			keys.append([&"factory", view.id])
	for view in warehouses:
		keys.append([&"warehouse", view.id])
	for lab_id in _sim.labs():
		keys.append([&"lab", lab_id])
	return keys


## Such as "Lab #1".
static func _lab_name(id: int) -> String:
	return "Lab #%d" % id


## Such as "Green factory #4".
func _factory_name(view: FactoryView) -> String:
	return "%s factory #%d" % [_content.color(view.color).name, view.id]


## Such as "Green warehouse #2".
func _warehouse_name(view: WarehouseView) -> String:
	return "%s warehouse #%d" % [_content.color(view.color).name, view.id]


## Such as "Red factory #1" or "Red warehouse #2".
func _source_name(view: LinkView) -> String:
	if view.source_kind == LinkView.Source.WAREHOUSE:
		return _warehouse_name(_sim.warehouse(view.source_warehouse_id))
	return _factory_name(_sim.factory(view.source_factory_id))


## Such as "Millbrook", "Green factory #4", or "Lab #1".
func _destination_name(view: LinkView) -> String:
	match view.destination_kind:
		LinkView.Destination.FACTORY:
			return _factory_name(_sim.factory(view.destination_factory_id))
		LinkView.Destination.WAREHOUSE:
			return _warehouse_name(_sim.warehouse(view.destination_warehouse_id))
		LinkView.Destination.LAB:
			return _lab_name(view.destination_lab_id)
	return _sim.market(view.destination_market_id).name


func _add_link_row(view: LinkView) -> LinkRow:
	var row := LinkRow.new(view, _content.color(view.color), _source_name(view), _destination_name(view))
	row.ship_pressed.connect(_on_ship_pressed)
	row.automate_pressed.connect(_on_automate_pressed)
	row.upgrade_vehicle_pressed.connect(_on_upgrade_vehicle_pressed)
	_link_rows[view.id] = row
	_link_list.add_child(row)
	return row


## Shows a split row for each source (a factory or a warehouse) with an
## automatic link, in the order of the first link from each source.
## [param links] are all links.
func _refresh_splits(links: Array[LinkView]) -> void:
	var by_source: Dictionary[String, Array] = {}
	var with_automatic := {}
	for view in links:
		var key := "%s_%d" % [LinkView.Source.find_key(view.source_kind).to_lower(),
			view.source_factory_id if view.source_kind == LinkView.Source.FACTORY else view.source_warehouse_id]
		if not by_source.has(key):
			by_source[key] = [] as Array[LinkView]
		by_source[key].append(view)
		if view.is_automatic():
			with_automatic[key] = true
	for key in by_source:
		if not with_automatic.has(key):
			continue
		var source_links: Array[LinkView] = by_source[key]
		var row: SplitRow = _split_rows.get(key)
		if row == null:
			var first := source_links[0]
			row = SplitRow.new(key, _source_name(first), _content.color(first.color))
			row.set_pressed.connect(_on_set_split_pressed)
			row.clear_pressed.connect(_on_clear_split_pressed)
			_split_rows[key] = row
			_split_list.add_child(row)
		var names: Dictionary[int, String] = {}
		for view in source_links:
			names[view.id] = _destination_name(view)
		row.show_state(source_links, names)
	_splits_empty_label.visible = _split_rows.is_empty()


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = not text.is_empty()


## Renders a color's symbol into a small, smooth texture for a button icon.
func _symbol_icon(color: ColorDef) -> Texture2D:
	const SIZE := 24.0
	var points := ColorSymbol.shape_points(color.symbol, Rect2(1.5, 1.5, SIZE - 3.0, SIZE - 3.0))
	var path := PackedStringArray()
	for point in points:
		path.append("%.2f,%.2f" % [point.x, point.y])
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d'><path d='M%sZ' fill='#%s' stroke='#%s' stroke-width='%.1f' stroke-linejoin='round'/></svg>" % [
		SIZE, SIZE, " L".join(path), color.display_color.to_html(false),
		ColorSymbol.OUTLINE_COLOR.to_html(false), ColorSymbol.OUTLINE_WIDTH]
	var image := Image.new()
	if points.is_empty() or image.load_svg_from_string(svg) != OK:
		return null
	return ImageTexture.create_from_image(image)
