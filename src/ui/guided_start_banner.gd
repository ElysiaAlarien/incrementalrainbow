class_name GuidedStartBanner
extends PanelContainer
## The guided start on the screen: the step that the player is at, what to do,
## and a button to skip the guide. It is not a dialog, so the player can do
## each step while it shows. It holds no rules: the core moves the guide on
## when it sees the action (see [GuidedStartView]), and the banner shows the
## step that [method Simulation.guided_start] gives. It hides when the guide is
## over.

signal skip_pressed

## What the player does at each step that the banner shows, in step order.
const STEP_TEXTS: Dictionary[GuidedStartView.Step, String] = {
	GuidedStartView.Step.BUILD_FACTORY:
		"Build a factory: in Colors, press Build factory on a color. A factory makes widgets of its color.",
	GuidedStartView.Step.MAKE_LINK:
		"In Links, make a link from your factory to a market. A link moves widgets of one color.",
	GuidedStartView.Step.START_SHIPMENT:
		"In Links, press Ship on your link. A shipment costs money and takes the transit time of the link.",
	GuidedStartView.Step.SELL:
		"Wait for the shipment to arrive. The market sells the widgets for money.",
}

var _step_label := Label.new()
var _text_label := Label.new()
var _skip_button := Button.new()


func _init() -> void:
	name = "GuidedStart"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.24, 0.36)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override(&"panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)

	_step_label.name = "GuidedStartStep"
	_step_label.add_theme_color_override(&"font_color", Color(0.75, 0.82, 1))
	_step_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_step_label)

	_text_label.name = "GuidedStartText"
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override(&"font_size", UiTheme.SMALL_FONT_SIZE)
	row.add_child(_text_label)

	_skip_button.name = "SkipGuidedStart"
	_skip_button.text = "Skip guide"
	_skip_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	row.add_child(_skip_button)


func show_state(view: GuidedStartView) -> void:
	visible = view.is_active()
	if not visible:
		return
	_step_label.text = "Guide %d / %d" % [STEP_TEXTS.keys().find(view.step) + 1, STEP_TEXTS.size()]
	_text_label.text = STEP_TEXTS[view.step]


## The text of the banner, for tests: such as
## "Guide 1 / 4: Build a factory. ...".
func text() -> String:
	return "%s: %s" % [_step_label.text, _text_label.text]

