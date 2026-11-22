class_name NumberStepper
extends HBoxContainer
## A whole number with a button on each side that steps it down or up. The
## buttons are large enough to touch, where the small arrows of a [SpinBox]
## are not. The player can also type the number, or use the mouse wheel over
## it.

## The box that holds the number. Its own arrows are hidden.
var spin_box := SpinBox.new()
var _down_button := Button.new()
var _up_button := Button.new()


func _init(min_value: float, max_value: float, suffix: String = "") -> void:
	add_theme_constant_override(&"separation", 4)
	_down_button.name = "Down"
	_down_button.text = "−"
	_down_button.custom_minimum_size = Vector2(UiScale.MIN_TOUCH_TARGET, UiScale.MIN_TOUCH_TARGET)
	_down_button.pressed.connect(func() -> void: spin_box.value -= spin_box.step)
	add_child(_down_button)

	spin_box.min_value = min_value
	spin_box.max_value = max_value
	spin_box.step = 1
	spin_box.suffix = suffix
	spin_box.select_all_on_focus = true
	spin_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hide_arrows(spin_box)
	spin_box.value_changed.connect(func(_value: float) -> void: _show_limits())
	add_child(spin_box)

	_up_button.name = "Up"
	_up_button.text = "+"
	_up_button.custom_minimum_size = Vector2(UiScale.MIN_TOUCH_TARGET, UiScale.MIN_TOUCH_TARGET)
	_up_button.pressed.connect(func() -> void: spin_box.value += spin_box.step)
	add_child(_up_button)
	_show_limits()


func down_button() -> Button:
	return _down_button


func up_button() -> Button:
	return _up_button


## Turns off a button at its limit, so that the player sees why it does
## nothing.
func _show_limits() -> void:
	_down_button.disabled = spin_box.value <= spin_box.min_value
	_up_button.disabled = spin_box.value >= spin_box.max_value


static func _hide_arrows(box: SpinBox) -> void:
	box.add_theme_constant_override(&"buttons_width", 0)
	box.add_theme_constant_override(&"set_min_buttons_width_from_icons", 0)
	box.add_theme_constant_override(&"field_and_buttons_separation", 0)
	var empty := PlaceholderTexture2D.new()
	empty.size = Vector2.ZERO
	for icon: StringName in [&"updown", &"up", &"up_hover", &"up_pressed", &"up_disabled", &"down",
			&"down_hover", &"down_pressed", &"down_disabled"]:
		box.add_theme_icon_override(icon, empty)
	for style: StringName in [&"up_background", &"up_background_hovered", &"up_background_pressed",
			&"up_background_disabled", &"down_background", &"down_background_hovered",
			&"down_background_pressed", &"down_background_disabled", &"field_and_buttons_separator",
			&"up_down_buttons_separator"]:
		box.add_theme_stylebox_override(style, StyleBoxEmpty.new())
