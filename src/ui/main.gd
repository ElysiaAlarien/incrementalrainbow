extends Control
## The first screen: build base factories, add production lines to them, and
## watch their output bays.
##
## The UI holds no game rules. It sends commands to the Simulation, ticks it
## each frame, and shows what the queries return. It loads the save on start,
## and saves at intervals and when the game exits or goes to the background.

## Seconds between saves while the game runs.
const AUTOSAVE_INTERVAL_S := 30.0

## Where the game keeps its save. Set it before the screen enters the tree.
var save_path := SaveFile.DEFAULT_PATH

@onready var _build_buttons: HBoxContainer = %BuildButtons
@onready var _factory_list: VBoxContainer = %FactoryList
@onready var _empty_label: Label = %EmptyLabel
@onready var _message_label: Label = %MessageLabel
@onready var _money_label: Label = %MoneyLabel

var _sim: Simulation
var _save_file: SaveFile
## False when a save that could not load is still at the save path, so that a
## save does not destroy it.
var _can_save := true
var _content: Content
var _rows: Dictionary[int, FactoryRow] = {}
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
	for color_id in _sim.buildable_factory_colors():
		_add_build_button(_content.color(color_id))
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


func _add_build_button(color: ColorDef) -> void:
	var button := Button.new()
	button.name = "Build_%s" % color.id
	button.text = "Build %s factory" % color.name
	button.icon = _symbol_icon(color)
	button.pressed.connect(_on_build_pressed.bind(color.id))
	_build_buttons.add_child(button)


func _on_build_pressed(color_id: StringName) -> void:
	var result := _sim.build_factory(color_id)
	_show_message("" if result.ok else result.message)
	_refresh()


func _on_add_line_requested(factory_id: int) -> void:
	var result := _sim.add_production_line(factory_id)
	_show_message("" if result.ok else result.message)
	_refresh()


func _refresh() -> void:
	_money_label.text = "Money: %s" % _sim.money().format()
	for view in _sim.factories():
		var row: FactoryRow = _rows.get(view.id)
		if row == null:
			row = FactoryRow.new(view.id, _content.color(view.color))
			row.add_line_requested.connect(_on_add_line_requested)
			_rows[view.id] = row
			_factory_list.add_child(row)
		row.show_state(view)
	_empty_label.visible = _rows.is_empty()


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
