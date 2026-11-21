class_name ColorCard
extends PanelContainer
## One color on the screen: its symbol, its name, its recipe, and a button to
## build a factory of it. A color that is not unlocked shows why instead of the
## button.

signal build_pressed(color_id: StringName)

const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const RECIPE_FONT_SIZE := 16
const WIDTH := 228

var color_id: StringName

var _recipe_parts: PackedStringArray = []
var _build_button := Button.new()
var _locked_label := Label.new()


## [param content] gives the input colors of the recipe.
func _init(color: ColorDef, content: Content) -> void:
	color_id = color.id
	name = "Color_%s" % color.id
	custom_minimum_size.x = WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	box.add_child(header)
	var symbol := ColorSymbol.new().setup(color)
	symbol.name = "Symbol"
	symbol.custom_minimum_size = Vector2(28, 28)
	header.add_child(symbol)
	var name_label := Label.new()
	name_label.text = color.name
	header.add_child(name_label)

	box.add_child(_recipe_line(color, content))

	_build_button.name = "Build_%s" % color.id
	_build_button.pressed.connect(func() -> void: build_pressed.emit(color_id))
	box.add_child(_build_button)
	_locked_label.name = "Locked"
	_locked_label.text = "Needs research"
	_locked_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	_locked_label.custom_minimum_size.y = _build_button.get_combined_minimum_size().y
	_locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_locked_label)


## The inputs of the recipe, each with its symbol, such as "▲ Yellow + ● Blue".
func _recipe_line(color: ColorDef, content: Content) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Recipe"
	line.add_theme_constant_override(&"separation", 4)
	var recipe := color.recipe
	if recipe.is_empty():
		line.add_child(_small_label("Base color: no inputs"))
		_recipe_parts.append("no inputs")
		return line
	for input in recipe:
		if not _recipe_parts.is_empty():
			line.add_child(_small_label("+"))
		var input_def := content.color(input)
		var part := input_def.name if recipe[input] == 1 else "%d %s" % [recipe[input], input_def.name]
		var symbol := ColorSymbol.new().setup(input_def)
		symbol.custom_minimum_size = Vector2(18, 18)
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(symbol)
		line.add_child(_small_label(part))
		_recipe_parts.append(part)
	return line


static func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", RECIPE_FONT_SIZE)
	label.add_theme_color_override(&"font_color", MUTED_COLOR)
	return label


## [param unlocked] is whether the player can build the color now.
func show_state(unlocked: bool, build_cost: BigNumber) -> void:
	_build_button.visible = unlocked
	_locked_label.visible = not unlocked
	_build_button.text = "Build factory (%s)" % build_cost.format()


## Such as "Yellow + Blue", "2 Red + Blue", or "no inputs".
func recipe_text() -> String:
	return " + ".join(_recipe_parts)


func build_button() -> Button:
	return _build_button


func is_locked() -> bool:
	return _locked_label.visible
