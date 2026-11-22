class_name PrestigeUpgradeRow
extends PanelContainer
## One prestige upgrade on the screen. The first line has its name, its price
## in prisms or "Owned", and a button to buy it. The second line has what it
## does.

signal buy_pressed(upgrade_id: StringName)

const MUTED_COLOR := Color(0.7, 0.72, 0.8)
const OWNED_COLOR := Color(0.6, 0.85, 0.6)

var upgrade_id: StringName

var _content: Content
var _name_label := Label.new()
var _status_label := Label.new()
var _buy_button := Button.new()
var _effects_label := Label.new()


func _init(view: PrestigeUpgradeView, content: Content) -> void:
	upgrade_id = view.id
	_content = content
	name = "PrestigeUpgrade_%s" % view.id
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 4)
	add_child(lines)

	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 16)
	lines.add_child(top)
	_name_label.text = view.name
	_name_label.custom_minimum_size.x = 260
	top.add_child(_name_label)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status_label)
	_buy_button.name = "Buy"
	_buy_button.text = "Buy"
	_buy_button.custom_minimum_size.x = 120
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit(upgrade_id))
	top.add_child(_buy_button)

	_effects_label.text = effects_text(view, content)
	_effects_label.add_theme_color_override(&"font_color", MUTED_COLOR)
	_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_effects_label)


## Shows whether the player owns the upgrade in [param view]. The button
## stays on when the player has too few prisms, so that a press shows why.
func show_state(view: PrestigeUpgradeView) -> void:
	_status_label.text = "Owned" if view.owned else "Price: %s" % prisms_text(view.price)
	_status_label.add_theme_color_override(&"font_color", OWNED_COLOR if view.owned else MUTED_COLOR)
	# Disable the button instead of hiding it, so the rows stay in line.
	_buy_button.disabled = view.owned


## The button that buys the upgrade. For smoke tests.
func buy_button() -> Button:
	return _buy_button


## All text of the row, for smoke tests.
func text() -> String:
	return " | ".join([_name_label.text, _status_label.text, _effects_label.text])


## Such as "1 prism" or "3 prisms".
static func prisms_text(count: int) -> String:
	return "%s %s" % [BigNumber.from_int(count).format(), "prism" if count == 1 else "prisms"]


## What [param view] does, such as "Factories make widgets 1.25 times as fast.
## Each run starts with 200 more money.".
static func effects_text(view: PrestigeUpgradeView, content: Content) -> String:
	var parts := PackedStringArray()
	if view.production_speed != 1.0:
		parts.append("Factories make widgets %s times as fast" % String.num(view.production_speed, 2))
	if not view.starting_money.is_zero():
		parts.append("Each run starts with %s more money" % view.starting_money.format())
	if not view.unlock_colors.is_empty():
		var names := PackedStringArray()
		for id in view.unlock_colors:
			names.append(content.color(id).name)
		parts.append("Unlocks %s" % ", ".join(names))
	return "%s." % ". ".join(parts)
