extends Control
## The first screen: build base factories and watch their output bays.
##
## The UI holds no game rules. It sends commands to the Simulation, ticks it
## each frame, and shows what the queries return.

@onready var _build_buttons: HBoxContainer = %BuildButtons
@onready var _factory_list: VBoxContainer = %FactoryList
@onready var _empty_label: Label = %EmptyLabel
@onready var _message_label: Label = %MessageLabel

var _sim: Simulation
var _rows: Dictionary[int, FactoryRow] = {}
## Frame time that is not yet a whole millisecond.
var _carry_ms: float = 0.0


func _ready() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	if not content.errors.is_empty():
		_show_message("The game data has errors:\n" + "\n".join(content.errors))
		set_process(false)
		return
	# Saves (a later ticket) will keep the seed; a new game takes a fresh one.
	_sim = Simulation.new(content, randi())
	for color_id in _sim.buildable_factory_colors():
		_add_build_button(content.color(color_id))
	_refresh()


func _process(delta: float) -> void:
	_carry_ms += delta * 1000.0
	var whole_ms := int(_carry_ms)
	_carry_ms -= whole_ms
	_sim.tick(whole_ms)
	_refresh()


## The simulation behind this screen. For smoke tests.
func simulation() -> Simulation:
	return _sim


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


func _refresh() -> void:
	for view in _sim.factories():
		var row: FactoryRow = _rows.get(view.id)
		if row == null:
			row = FactoryRow.new(view.id, _sim.content().color(view.color))
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
