extends Control
## The first screen: money, prisms, each color with its recipe and a button to
## build it, factories with their production lines, output bays, and input
## bays, warehouses with their widgets and throughput, links from factories and
## warehouses to markets, mixed factories, and warehouses, with manual
## shipments, automatic transport, and throughput, the active demand events,
## and markets with their population, income, capacity, community investment,
## and the price and demand of each color.
##
## The UI holds no game rules. It sends commands to the Simulation, ticks it
## each frame, and shows what the queries return. It loads the save on start,
## and saves at intervals and when the game exits or goes to the background.
## The Export or import button exports the game as a code and imports a code.
## The Prestige button shows what a prestige keeps and clears, and asks the
## player to confirm.

## Seconds between saves while the game runs.
const AUTOSAVE_INTERVAL_S := 30.0

## Where the game keeps its save. Set it before the screen enters the tree.
var save_path := SaveFile.DEFAULT_PATH

@onready var _color_cards: HFlowContainer = %ColorCards
@onready var _factory_list: VBoxContainer = %FactoryList
@onready var _empty_label: Label = %EmptyLabel
@onready var _new_warehouse_color: OptionButton = %NewWarehouseColor
@onready var _build_warehouse_button: Button = %BuildWarehouse
@onready var _warehouse_locked_label: Label = %WarehouseLockedLabel
@onready var _warehouse_list: VBoxContainer = %WarehouseList
@onready var _warehouses_empty_label: Label = %WarehousesEmptyLabel
@onready var _new_link_source: OptionButton = %NewLinkSource
@onready var _new_link_destination: OptionButton = %NewLinkDestination
@onready var _make_link_button: Button = %MakeLink
@onready var _link_list: VBoxContainer = %LinkList
@onready var _links_empty_label: Label = %LinksEmptyLabel
@onready var _demand_event_list: VBoxContainer = %DemandEventList
@onready var _demand_events_empty_label: Label = %DemandEventsEmptyLabel
@onready var _market_list: VBoxContainer = %MarketList
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
var _market_rows: Dictionary[StringName, MarketRow] = {}
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
## Frame time that is not yet a whole millisecond.
var _carry_ms: float = 0.0


func _ready() -> void:
	_content = Content.load_dir(Content.DEFAULT_DIR)
	if not _content.errors.is_empty():
		_show_message("The game data has errors:\n" + "\n".join(_content.errors))
		set_process(false)
		return
	_save_file = SaveFile.new(save_path)
	_sim = _load_or_start_game()
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
	_export_code_button.pressed.connect(func() -> void: _export_code_dialog.open(_sim))
	_buy_prism_button.pressed.connect(_on_buy_prism_pressed)
	_prestige_confirm.name = "PrestigeConfirm"
	_prestige_confirm.title = "Prestige?"
	_prestige_confirm.ok_button_text = "Prestige"
	_prestige_confirm.confirmed.connect(_on_prestige_confirmed)
	add_child(_prestige_confirm)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	_refresh()


func _process(delta: float) -> void:
	_carry_ms += delta * 1000.0
	var whole_ms := int(_carry_ms)
	_carry_ms -= whole_ms
	_sim.tick(whole_ms)
	_refresh()


func _exit_tree() -> void:
	# The scene tree removes this screen when the game quits by any path.
	write_save()


func _notification(what: int) -> void:
	# A mobile OS can stop a game in the background with no other notice.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		write_save()


## Writes the current game to the device.
func write_save() -> void:
	if _sim == null or not _can_save:
		return
	var error := _save_file.write(SaveCodec.encode(_sim))
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
			return result.simulation
		var kept_path := _save_file.keep_damaged()
		var kept_text := "A copy of it is at %s." % ProjectSettings.globalize_path(kept_path)
		if kept_path.is_empty():
			_can_save = false
			kept_text = "The game could not move it, so this game will not save. Your save stays at %s." % \
				ProjectSettings.globalize_path(_save_file.path)
		push_warning("The save did not load: %s" % result.message)
		_show_message("Your save could not load, so a new game started. %s\n%s" % [kept_text, result.message])
	return Simulation.new(_content, randi())


## Replaces the game with [param simulation], from an imported code, and saves
## it at once.
func _replace_game(simulation: Simulation) -> void:
	_sim = simulation
	_show_replaced_run()


## Shows the run of the game after an import or a prestige replaced the last
## run. It removes the rows of the last run, and saves the game at once.
func _show_replaced_run() -> void:
	for row: Node in _rows.values() + _link_rows.values() + _warehouse_rows.values():
		row.get_parent().remove_child(row)
		row.queue_free()
	_rows.clear()
	_link_rows.clear()
	_warehouse_rows.clear()
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
		_:
			_show_message("A warehouse cannot link to another warehouse. Link it to a market or a mixed factory.")


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


func _show_result(result: CommandResult) -> void:
	_show_message("" if result.ok else result.message)
	_refresh()


func _on_add_line_requested(factory_id: int) -> void:
	_show_result(_sim.add_production_line(factory_id))


func _refresh() -> void:
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
	_refresh_new_link_choices()

	var automatic_cost := _sim.automatic_transport_cost()
	for view in _sim.links():
		var link_row: LinkRow = _link_rows.get(view.id)
		if link_row == null:
			link_row = _add_link_row(view)
		link_row.show_state(view, automatic_cost)
	_links_empty_label.visible = _link_rows.is_empty()

	_refresh_demand_events()

	for view in _sim.markets():
		var market_row: MarketRow = _market_rows.get(view.id)
		if market_row == null:
			market_row = MarketRow.new(view, _content.colors())
			market_row.invest_pressed.connect(_on_invest_pressed)
			_market_rows[view.id] = market_row
			_market_list.add_child(market_row)
		market_row.show_state(view)


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
			_warehouse_rows[view.id] = row
			_warehouse_list.add_child(row)
		row.show_state(view)
	_warehouses_empty_label.visible = _warehouse_rows.is_empty()


func _add_factory_row(view: FactoryView) -> FactoryRow:
	var row := FactoryRow.new(view.id, _content.color(view.color), _content)
	row.add_line_requested.connect(_on_add_line_requested)
	_rows[view.id] = row
	_factory_list.add_child(row)
	return row


## Keeps the source and destination choices for a new link in step with the
## simulation. Each choice has a key: [code][kind, id][/code], where the kind
## is &"factory", &"warehouse", or &"market". The sources are the factories,
## then the warehouses. The destinations are the markets, then the mixed
## factories, then the warehouses. When a list changes, it is made again with
## the same place selected.
func _refresh_new_link_choices() -> void:
	var factories := _sim.factories()
	var warehouses := _sim.warehouses()
	_source_keys = _refresh_choice(_new_link_source, _source_keys, _link_source_keys(factories, warehouses))
	_destination_keys = _refresh_choice(_new_link_destination, _destination_keys,
		_link_destination_keys(factories, warehouses))


## Fills [param choice] with an item for each of [param keys] when they are not
## [param old_keys], and keeps the selected key. Returns [param keys].
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
			_:
				choice.add_item(_sim.market(key[1]).name)
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
## each warehouse.
func _link_destination_keys(factories: Array[FactoryView], warehouses: Array[WarehouseView]) -> Array:
	var keys: Array = []
	for market in _sim.markets():
		keys.append([&"market", market.id])
	for view in factories:
		if not view.input_bays.is_empty():
			keys.append([&"factory", view.id])
	for view in warehouses:
		keys.append([&"warehouse", view.id])
	return keys


## Such as "Green factory #4".
func _factory_name(view: FactoryView) -> String:
	return "%s factory #%d" % [_content.color(view.color).name, view.id]


## Such as "Green warehouse #2".
func _warehouse_name(view: WarehouseView) -> String:
	return "%s warehouse #%d" % [_content.color(view.color).name, view.id]


func _add_link_row(view: LinkView) -> LinkRow:
	var source_name := _factory_name(_sim.factory(view.source_factory_id)) \
		if view.source_kind == LinkView.Source.FACTORY else _warehouse_name(_sim.warehouse(view.source_warehouse_id))
	var destination_name := ""
	match view.destination_kind:
		LinkView.Destination.FACTORY:
			destination_name = _factory_name(_sim.factory(view.destination_factory_id))
		LinkView.Destination.WAREHOUSE:
			destination_name = _warehouse_name(_sim.warehouse(view.destination_warehouse_id))
		_:
			destination_name = _sim.market(view.destination_market_id).name
	var row := LinkRow.new(view, _content.color(view.color), source_name, destination_name,
		_content.transport_tier(view.vehicle).name)
	row.ship_pressed.connect(_on_ship_pressed)
	row.automate_pressed.connect(_on_automate_pressed)
	_link_rows[view.id] = row
	_link_list.add_child(row)
	return row


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
