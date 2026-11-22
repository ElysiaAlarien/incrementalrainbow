class_name UiTheme
extends RefCounted
## The look of the game: flat colors, rounded corners, and no images, so it
## stays sharp at each scale. Each control that the player presses is at least
## [constant UiScale.MIN_TOUCH_TARGET] high, from the font size and the content
## margins here. The main screen uses this theme, and its dialogs get it from
## the screen.

const FONT_SIZE := 18
const SMALL_FONT_SIZE := 15
const HEADING_FONT_SIZE := 22

const BACKGROUND_COLOR := Color(0.11, 0.12, 0.17)
const PANEL_COLOR := Color(0.155, 0.17, 0.225)
const TEXT_COLOR := Color(0.93, 0.94, 0.97)
const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const DISABLED_TEXT_COLOR := Color(0.55, 0.57, 0.64)
const BUTTON_COLOR := Color(0.23, 0.26, 0.35)
const BUTTON_HOVER_COLOR := Color(0.28, 0.32, 0.43)
const BUTTON_PRESSED_COLOR := Color(0.34, 0.4, 0.58)
const BUTTON_DISABLED_COLOR := Color(0.18, 0.195, 0.25)
const ACCENT_COLOR := Color(0.55, 0.66, 1.0)
const FIELD_COLOR := Color(0.09, 0.1, 0.14)

const CORNER_RADIUS := 8
## The space between the items of a list. With the font, it makes each item
## [constant UiScale.MIN_TOUCH_TARGET] high or more.
const POPUP_ITEM_SEPARATION := 20
## The space around the text of a button. With the font, it makes a button
## [constant UiScale.MIN_TOUCH_TARGET] high or more.
const BUTTON_MARGIN := Vector2(14, 10)

## A label in the muted color and the small font size.
const MUTED_LABEL := &"MutedLabel"
## The heading of a part of a section.
const HEADING_LABEL := &"HeadingLabel"
## A button of the section rail, which shows the section that is open.
const RAIL_BUTTON := &"RailButton"


## The theme of the main screen and its dialogs.
static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	theme.set_color(&"font_color", &"Label", TEXT_COLOR)
	theme.set_type_variation(MUTED_LABEL, &"Label")
	theme.set_color(&"font_color", MUTED_LABEL, MUTED_COLOR)
	theme.set_font_size(&"font_size", MUTED_LABEL, SMALL_FONT_SIZE)
	theme.set_type_variation(HEADING_LABEL, &"Label")
	theme.set_font_size(&"font_size", HEADING_LABEL, HEADING_FONT_SIZE)

	theme.set_stylebox(&"panel", &"PanelContainer", box(PANEL_COLOR, Vector2(12, 10)))
	theme.set_stylebox(&"panel", &"Panel", box(PANEL_COLOR, Vector2.ZERO))

	for type: StringName in [&"Button", &"OptionButton", &"MenuButton", &"CheckBox", &"CheckButton"]:
		_button_styles(theme, type)
	theme.set_type_variation(RAIL_BUTTON, &"Button")
	theme.set_stylebox(&"normal", RAIL_BUTTON, box(Color(0, 0, 0, 0), BUTTON_MARGIN))
	theme.set_stylebox(&"hover", RAIL_BUTTON, box(BUTTON_COLOR, BUTTON_MARGIN))
	theme.set_stylebox(&"pressed", RAIL_BUTTON, box(BUTTON_PRESSED_COLOR, BUTTON_MARGIN))
	theme.set_stylebox(&"hover_pressed", RAIL_BUTTON, box(BUTTON_PRESSED_COLOR, BUTTON_MARGIN))
	theme.set_color(&"font_color", RAIL_BUTTON, MUTED_COLOR)
	theme.set_color(&"font_pressed_color", RAIL_BUTTON, TEXT_COLOR)
	theme.set_color(&"font_hover_pressed_color", RAIL_BUTTON, TEXT_COLOR)
	theme.set_constant(&"align_to_largest_stylebox", RAIL_BUTTON, 1)

	# An item of a list, such as the colors of a choice, is as high as a touch
	# target: the font is about 25 high.
	theme.set_constant(&"v_separation", &"PopupMenu", POPUP_ITEM_SEPARATION)
	theme.set_constant(&"item_start_padding", &"PopupMenu", 12)
	theme.set_constant(&"item_end_padding", &"PopupMenu", 12)
	theme.set_constant(&"h_separation", &"PopupMenu", 10)
	theme.set_constant(&"icon_max_width", &"PopupMenu", 24)
	theme.set_stylebox(&"panel", &"PopupMenu", box(PANEL_COLOR.lightened(0.05), Vector2(4, 4)))
	theme.set_stylebox(&"hover", &"PopupMenu", box(BUTTON_HOVER_COLOR, Vector2.ZERO))
	theme.set_color(&"font_color", &"PopupMenu", TEXT_COLOR)
	theme.set_color(&"font_disabled_color", &"PopupMenu", DISABLED_TEXT_COLOR)

	for type: StringName in [&"LineEdit", &"TextEdit"]:
		theme.set_stylebox(&"normal", type, box(FIELD_COLOR, BUTTON_MARGIN, BUTTON_COLOR))
		theme.set_stylebox(&"focus", type, box(Color(0, 0, 0, 0), BUTTON_MARGIN, ACCENT_COLOR))
		theme.set_stylebox(&"read_only", type, box(FIELD_COLOR, BUTTON_MARGIN, BUTTON_DISABLED_COLOR))
		theme.set_color(&"font_color", type, TEXT_COLOR)
	theme.set_constant(&"minimum_character_width", &"LineEdit", 3)

	var bar := box(BUTTON_COLOR, Vector2.ZERO)
	bar.set_corner_radius_all(4)
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		var scroll := StyleBoxFlat.new()
		scroll.bg_color = Color(0, 0, 0, 0)
		scroll.set_content_margin_all(3)
		theme.set_stylebox(&"scroll", type, scroll)
		theme.set_stylebox(&"grabber", type, bar)
		theme.set_stylebox(&"grabber_highlight", type, box(BUTTON_HOVER_COLOR, Vector2(4, 4)))
		theme.set_stylebox(&"grabber_pressed", type, box(BUTTON_PRESSED_COLOR, Vector2(4, 4)))

	theme.set_stylebox(&"panel", &"AcceptDialog", box(PANEL_COLOR, Vector2(16, 12)))
	theme.set_stylebox(&"embedded_border", &"Window", _window_border())
	theme.set_stylebox(&"embedded_unfocused_border", &"Window", _window_border())
	theme.set_font_size(&"title_font_size", &"Window", FONT_SIZE)
	# The title bar holds the close button, so it is as high as a touch target.
	theme.set_constant(&"title_height", &"Window", int(UiScale.MIN_TOUCH_TARGET))
	theme.set_color(&"title_color", &"Window", TEXT_COLOR)
	theme.set_stylebox(&"panel", &"TooltipPanel", box(FIELD_COLOR, Vector2(10, 6), BUTTON_COLOR))
	theme.set_font_size(&"font_size", &"TooltipLabel", SMALL_FONT_SIZE)
	return theme


## A flat box of [param color] with rounded corners and content margins of
## [param margin]. A [param border] color gives it a thin border.
static func box(color: Color, margin: Vector2, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(2)
	style.anti_aliasing = true
	return style


static func _button_styles(theme: Theme, type: StringName) -> void:
	theme.set_stylebox(&"normal", type, box(BUTTON_COLOR, BUTTON_MARGIN))
	theme.set_stylebox(&"hover", type, box(BUTTON_HOVER_COLOR, BUTTON_MARGIN))
	theme.set_stylebox(&"pressed", type, box(BUTTON_PRESSED_COLOR, BUTTON_MARGIN))
	theme.set_stylebox(&"hover_pressed", type, box(BUTTON_PRESSED_COLOR, BUTTON_MARGIN))
	theme.set_stylebox(&"disabled", type, box(BUTTON_DISABLED_COLOR, BUTTON_MARGIN))
	var focus := box(Color(0, 0, 0, 0), BUTTON_MARGIN, ACCENT_COLOR)
	focus.draw_center = false
	theme.set_stylebox(&"focus", type, focus)
	theme.set_color(&"font_color", type, TEXT_COLOR)
	theme.set_color(&"font_hover_color", type, TEXT_COLOR)
	theme.set_color(&"font_pressed_color", type, TEXT_COLOR)
	theme.set_color(&"font_hover_pressed_color", type, TEXT_COLOR)
	theme.set_color(&"font_focus_color", type, TEXT_COLOR)
	theme.set_color(&"font_disabled_color", type, DISABLED_TEXT_COLOR)
	theme.set_constant(&"h_separation", type, 8)
	theme.set_constant(&"icon_max_width", type, 24)


static func _window_border() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR.lightened(0.05)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.expand_margin_left = 6
	style.expand_margin_right = 6
	style.expand_margin_bottom = 6
	style.expand_margin_top = UiScale.MIN_TOUCH_TARGET
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	return style


## A line of controls that wraps to more lines when they do not fit. Each
## control keeps its own width, so that rows line up on a wide screen.
static func flow(h_separation: int = 16) -> HFlowContainer:
	var line := HFlowContainer.new()
	line.add_theme_constant_override(&"h_separation", h_separation)
	line.add_theme_constant_override(&"v_separation", 6)
	return line


## A label that wraps to more lines when its text does not fit, and fills the
## width. Use it for text that can be longer than a small screen is wide.
static func wrapping_label(muted: bool = false) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if muted:
		label.theme_type_variation = MUTED_LABEL
	return label


## The first line of a row: a symbol and a title that wraps. Returns the line.
static func title_line(symbol: Control, title: Label) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	symbol.custom_minimum_size = Vector2(28, 28)
	symbol.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(symbol)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(title)
	return line


## A label that holds at least [param width] logical pixels, so that the
## columns of rows line up on a wide screen.
static func column_label(width: float, muted: bool = false) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = width
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if muted:
		label.theme_type_variation = MUTED_LABEL
	return label
