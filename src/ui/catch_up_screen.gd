class_name CatchUpScreen
extends Control
## Covers the main screen while offline progress is applied, and shows how far
## it is. It stops input, because the player cannot act until the game has
## caught up. It holds no rules.

const BACKGROUND_COLOR := Color(0.07, 0.08, 0.11, 0.92)
const BAR_SIZE := Vector2(480, 28)
const BAR_BACKGROUND_COLOR := Color(0.2, 0.22, 0.3)
const BAR_FILL_COLOR := Color(0.98, 0.85, 0.45)

var _label := Label.new()
var _bar := ProgressBar.new()


func _init() -> void:
	name = "CatchUpScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 16)
	center.add_child(layout)
	var title := Label.new()
	title.text = "Catching up on the time you were away"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 28)
	layout.add_child(title)
	_bar.name = "CatchUpProgress"
	_bar.custom_minimum_size = BAR_SIZE
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override(&"background", _bar_style(BAR_BACKGROUND_COLOR))
	_bar.add_theme_stylebox_override(&"fill", _bar_style(BAR_FILL_COLOR))
	layout.add_child(_bar)
	_label.name = "CatchUpText"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_label)


## Shows the screen with [param done_ms] of offline progress applied and
## [param pending_ms] still to apply.
func show_progress(done_ms: int, pending_ms: int) -> void:
	var total_ms := done_ms + pending_ms
	_bar.value = 0.0 if total_ms <= 0 else float(done_ms) / total_ms
	_label.text = "%s of %s" % [OfflineSummaryDialog.format_duration(done_ms),
		OfflineSummaryDialog.format_duration(total_ms)]
	visible = true


static func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	return style
