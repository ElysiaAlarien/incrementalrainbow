class_name DialogFit
extends RefCounted
## Keeps a dialog inside the screen. The content of the dialog goes in a
## scroll container, so that a long text scrolls on a short screen, such as a
## phone in landscape. A wide content shrinks to the screen width, and its text
## wraps.

## The space between a dialog and the edge of the screen.
const SCREEN_MARGIN := 16.0


## Puts [param content] in a scroll container in [param dialog], and returns
## the container. Call [method popup] to show the dialog.
static func wrap(dialog: AcceptDialog, content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	dialog.add_child(scroll)
	return scroll


## Shows [param dialog] in the middle of its screen. Its content in
## [param scroll] is [param width] wide, or the width of the screen when that
## is less, and as high as it needs, or the height of the screen when that is
## less. Call it again while the dialog shows to fit a changed content.
static func popup(dialog: AcceptDialog, scroll: ScrollContainer, width: float) -> void:
	var screen := dialog.get_parent().get_viewport().get_visible_rect().size
	var content: Control = scroll.get_child(0)
	scroll.custom_minimum_size = Vector2.ZERO
	content.custom_minimum_size.x = 0.0
	dialog.reset_size()
	# The title, the buttons, and the margins of the dialog.
	var frame := dialog.get_contents_minimum_size() - scroll.get_combined_minimum_size()
	var title := float(dialog.get_theme_constant(&"title_height", &"Window"))
	var room := screen - Vector2(frame.x, frame.y + title) - Vector2.ONE * SCREEN_MARGIN * 2.0
	var content_width := minf(width, room.x)
	content.custom_minimum_size.x = content_width
	scroll.custom_minimum_size = Vector2(content_width, minf(content.get_combined_minimum_size().y, room.y))
	dialog.reset_size()
	if dialog.visible:
		dialog.move_to_center()
	else:
		dialog.popup_centered()
	# Wrapped text knows its height only after the containers give it its
	# width, at the end of this frame.
	_fit_height.call_deferred(dialog, scroll, room.y)


static func _fit_height(dialog: AcceptDialog, scroll: ScrollContainer, room_height: float) -> void:
	if not is_instance_valid(dialog) or not dialog.visible:
		return
	var content: Control = scroll.get_child(0)
	var height := minf(content.get_combined_minimum_size().y, room_height)
	if is_equal_approx(height, scroll.custom_minimum_size.y):
		return
	scroll.custom_minimum_size.y = height
	dialog.reset_size()
	dialog.move_to_center()
