class_name ColorCard
extends PanelContainer
## One color on the screen: its symbol, its name, its recipe, and a button to
## build a factory of it. A color that is not unlocked shows why instead of the
## button. The card fills the width of its column in a [CardGrid], and the
## recipe wraps to more lines when it does not fit.

signal build_pressed(color_id: StringName)


var color_id: StringName

var _recipe_parts: PackedStringArray = []
var _build_button := Button.new()
var _locked_label := Label.new()
## Why the color is locked when its own unlock is not met, such as
## "Needs research:\nEarth tones".
var _unlock_text := ""


## [param content] gives the input colors of the recipe.
func _init(color: ColorDef, content: Content) -> void:
	color_id = color.id
	name = "Color_%s" % color.id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)

	box.add_child(_recipe_line(color, content))
	# Keeps the button at the bottom, so that the buttons of a row of cards
	# line up when a recipe wraps.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	_build_button.name = "Build_%s" % color.id
	_build_button.pressed.connect(func() -> void: build_pressed.emit(color_id))
	box.add_child(_build_button)
	_locked_label.name = "Locked"
	var needs := "a prestige upgrade" if color.unlock == ColorDef.Unlock.PRESTIGE_UPGRADE else "research"
	_unlock_text = "Needs %s:\n%s" % [needs, " or ".join(content.unlocker_names(color))]
	_locked_label.text = _unlock_text
	# The name can be long, so the text is small and can wrap to two
	# lines in the height of the button.
	_locked_label.theme_type_variation = UiTheme.MUTED_LABEL
	_locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_locked_label.add_theme_constant_override(&"line_spacing", -2)
	_locked_label.custom_minimum_size.y = UiScale.MIN_TOUCH_TARGET
	_locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_locked_label)


## The inputs of the recipe, each with its symbol, such as "▲ Yellow + ● Blue".
func _recipe_line(color: ColorDef, content: Content) -> HFlowContainer:
	var line := HFlowContainer.new()
	line.name = "Recipe"
	line.add_theme_constant_override(&"h_separation", 4)
	line.add_theme_constant_override(&"v_separation", 2)
	var recipe := color.recipe
	if recipe.is_empty():
		line.add_child(_small_label("Base color: no inputs"))
		_recipe_parts.append("no inputs")
		return line
	for input in recipe:
		var input_def := content.color(input)
		var part := input_def.name if recipe[input] == 1 else "%d %s" % [recipe[input], input_def.name]
		# Each input with its symbol, and the "+" before it, stays on one line.
		var item := HBoxContainer.new()
		item.add_theme_constant_override(&"separation", 4)
		if not _recipe_parts.is_empty():
			item.add_child(_small_label("+"))
		var symbol := ColorSymbol.new().setup(input_def)
		symbol.custom_minimum_size = Vector2(18, 18)
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(symbol)
		item.add_child(_small_label(part))
		line.add_child(item)
		_recipe_parts.append(part)
	return line


static func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.MUTED_LABEL
	return label


## [param unlocked] is whether the player can build the color now. When the
## own unlock of the color is met but recipe inputs are still locked,
## [param locked_inputs] has their names, such as ["Red-orange"].
func show_state(unlocked: bool, build_cost: BigNumber,
		locked_inputs: PackedStringArray = PackedStringArray()) -> void:
	_build_button.visible = unlocked
	_locked_label.visible = not unlocked
	_locked_label.text = _unlock_text if locked_inputs.is_empty() \
		else "Needs %s first" % " and ".join(locked_inputs)
	_build_button.text = "Build factory (%s)" % build_cost.format()


## Such as "Yellow + Blue", "2 Red + Blue", or "no inputs".
func recipe_text() -> String:
	return " + ".join(_recipe_parts)


func build_button() -> Button:
	return _build_button


## Why the color is locked, such as "Needs research:\nEarth tones" or
## "Needs Red-orange first".
func locked_text() -> String:
	return _locked_label.text


func is_locked() -> bool:
	return _locked_label.visible
