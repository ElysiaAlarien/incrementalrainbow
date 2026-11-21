class_name ColorSymbol
extends Control
## Draws a color's symbol: a flat shape filled with the color, with an outline,
## so that colorblind players can tell colors apart by shape.

const OUTLINE_COLOR := Color(0.06, 0.07, 0.1)
const OUTLINE_WIDTH := 2.0

var symbol: StringName = &"":
	set(value):
		symbol = value
		queue_redraw()
var fill: Color = Color.WHITE:
	set(value):
		fill = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(28, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(color: ColorDef) -> ColorSymbol:
	symbol = color.symbol
	fill = color.display_color
	tooltip_text = color.name
	return self


func _draw() -> void:
	var side := minf(size.x, size.y) - OUTLINE_WIDTH * 2.0
	var box := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	var points := ColorSymbol.shape_points(symbol, box)
	if points.is_empty():
		# An unknown symbol is a content bug; show it clearly instead of hiding it.
		draw_rect(box, fill, false, OUTLINE_WIDTH)
		draw_line(box.position, box.end, fill, OUTLINE_WIDTH)
		return
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUTLINE_COLOR, OUTLINE_WIDTH, true)


## The outline of [param symbol] inside [param box], or an empty array for an
## unknown symbol. Add new symbols here when the content adds them.
static func shape_points(symbol: StringName, box: Rect2) -> PackedVector2Array:
	var c := box.get_center()
	var r := box.size.x / 2.0
	match symbol:
		&"square":
			var inset := r * 0.12
			var b := box.grow(-inset)
			return PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)])
		&"triangle":
			return PackedVector2Array([Vector2(c.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
		&"circle":
			return _regular_polygon(c, r, 48, 0.0)
	return PackedVector2Array()


static func _regular_polygon(center: Vector2, radius: float, sides: int, start_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle := start_angle + TAU * i / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
