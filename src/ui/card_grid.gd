class_name CardGrid
extends GridContainer
## A grid that has as many columns as fit its width, each at least
## [member min_column_width] wide, and at least as wide as its widest child. The cells fill the width, so the grid has no
## empty space at its right edge. Its children should expand horizontally.

## The narrowest that a column can be, in logical pixels.
@export var min_column_width := 200.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_columns()


func _fit_columns() -> void:
	var gap := float(get_theme_constant(&"h_separation"))
	var column := min_column_width
	for child in get_children():
		if child is Control and child.visible:
			column = maxf(column, (child as Control).get_combined_minimum_size().x)
	var fit := maxi(int((size.x + gap) / (column + gap)), 1)
	if fit != columns:
		columns = fit
