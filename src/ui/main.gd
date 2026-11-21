extends Control
## The first screen: money, base factories with their production lines and
## output bays, and links from factories to markets with manual shipments,
## automatic transport, and throughput.
##
## The UI holds no game rules. It sends commands to the Simulation, ticks it
## each frame, and shows what the queries return. It loads the save on start,
## and saves at intervals and when the game exits or goes to the background.
## The Export or import button exports the game as a code and imports a code.

## Seconds between saves while the game runs.
const AUTOSAVE_INTERVAL_S := 30.0

## Where the game keeps its save. Set it before the screen enters the tree.
var save_path := SaveFile.DEFAULT_PATH

@onready var _build_buttons: HBoxContainer = %BuildButtons
@onready var _factory_list: VBoxContainer = %FactoryList
@onready var _empty_label: Label = %EmptyLabel
@onready var _new_link_factory: OptionButton = %NewLinkFactory
@onready var _new_link_market: OptionButton = %NewLinkMarket
@onready var _make_link_button: Button = %MakeLink
@onready var _link_list: VBoxContainer = %LinkList
@onready var _links_empty_label: Label = %LinksEmptyLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _message_label: Label = %MessageLabel
@onready var _export_code_button: Button = %ExportCodeButton

var _sim: Simulation
var _save_file: SaveFile
## False when a save that could not load is still at the save path, so that a
## save does not destroy it.
var _can_save := true
var _content: Content
var _rows: Dictionary[int, FactoryRow] = {}
var _link_rows: Dictionary[int, LinkRow] = {}
var _build_button_by_color: Dictionary[StringName, Button] = {}
var _export_code_dialog: ExportCodeDialog
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
	_add_build_buttons()
	_make_link_button.pressed.connect(_on_make_link_pressed)
	_export_code_dialog = ExportCodeDialog.new(_content)
	_export_code_dialog.import_confirmed.connect(_replace_game)
	add_child(_export_code_dialog)
	_export_code_button.pressed.connect(func() -> void: _export_code_dialog.open(_sim))
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
	for row: Node in _rows.values() + _link_rows.values():
		row.get_parent().remove_child(row)
		row.queue_free()
	_rows.clear()
	_link_rows.clear()
	_new_link_factory.clear()
	_new_link_market.clear()
	for button in _build_button_by_color.values():
		_build_buttons.remove_child(button)
		button.queue_free()
	_build_button_by_color.clear()
	_add_build_buttons()
	_show_message("")
	write_save()
	_refresh()


func _add_build_buttons() -> void:
	for color_id in _sim.buildable_factory_colors():
		_add_build_button(_content.color(color_id))


func _add_build_button(color: ColorDef) -> void:
	var button := Button.new()
	button.name = "Build_%s" % color.id
	button.text = "Build %s factory" % color.name
	button.icon = _symbol_icon(color)
	button.pressed.connect(_on_build_pressed.bind(color.id))
	_build_buttons.add_child(button)
	_build_button_by_color[color.id] = button


func _on_build_pressed(color_id: StringName) -> void:
	_show_result(_sim.build_factory(color_id))


func _on_make_link_pressed() -> void:
	var factory_index := _new_link_factory.selected
	var market_index := _new_link_market.selected
	if factory_index < 0 or market_index < 0:
		_show_message("Build a factory first.")
		return
	_show_result(_sim.make_link(_new_link_factory.get_item_id(factory_index),
		_new_link_market.get_item_metadata(market_index)))


func _on_ship_pressed(link_id: int) -> void:
	_show_result(_sim.start_shipment(link_id))


func _on_automate_pressed(link_id: int) -> void:
	_show_result(_sim.buy_automatic_transport(link_id))


func _show_result(result: CommandResult) -> void:
	_show_message("" if result.ok else result.message)
	_refresh()


func _on_add_line_requested(factory_id: int) -> void:
	_show_result(_sim.add_production_line(factory_id))


func _refresh() -> void:
	_money_label.text = "Money: %s" % _sim.money().format()
	var cost := _sim.factory_build_cost().format()
	for color_id in _build_button_by_color:
		_build_button_by_color[color_id].text = "Build %s factory (%s)" % [_content.color(color_id).name, cost]

	for view in _sim.factories():
		var row: FactoryRow = _rows.get(view.id)
		if row == null:
			row = _add_factory_row(view)
		row.show_state(view)
	_empty_label.visible = _rows.is_empty()
	_refresh_new_link_choices()

	var automatic_cost := _sim.automatic_transport_cost()
	for view in _sim.links():
		var link_row: LinkRow = _link_rows.get(view.id)
		if link_row == null:
			link_row = _add_link_row(view)
		link_row.show_state(view, automatic_cost)
	_links_empty_label.visible = _link_rows.is_empty()


func _add_factory_row(view: FactoryView) -> FactoryRow:
	var row := FactoryRow.new(view.id, _content.color(view.color))
	row.add_line_requested.connect(_on_add_line_requested)
	_rows[view.id] = row
	_factory_list.add_child(row)
	return row


## Keeps the factory and market choices for a new link in step with the
## simulation. Items are added, never removed, so the selection stays.
func _refresh_new_link_choices() -> void:
	var factories := _sim.factories()
	for i in range(_new_link_factory.item_count, factories.size()):
		var view := factories[i]
		var color := _content.color(view.color)
		_new_link_factory.add_icon_item(_symbol_icon(color), "%s factory #%d" % [color.name, view.id], view.id)
	var markets := _sim.markets()
	for i in range(_new_link_market.item_count, markets.size()):
		_new_link_market.add_item(markets[i].name)
		_new_link_market.set_item_metadata(i, markets[i].id)


func _add_link_row(view: LinkView) -> LinkRow:
	var row := LinkRow.new(view, _content.color(view.color), _sim.market(view.destination_market_id).name,
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
