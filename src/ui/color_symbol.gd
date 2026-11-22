class_name ColorSymbol
extends Control
## Draws a color's symbol: a flat shape filled with the color, with an outline,
## so that colorblind players can tell colors apart by shape. A tint or a shade
## also has its mark: a small dot, white at the top right for a tint, and
## black at the bottom right for a shade.

const OUTLINE_COLOR := Color(0.06, 0.07, 0.1)
## The outline of a dark fill, such as black, so that it shows on the dark
## background.
const LIGHT_OUTLINE_COLOR := Color(0.86, 0.87, 0.9)
const OUTLINE_WIDTH := 2.0
## A fill with a luminance below this gets the light outline.
const DARK_FILL_LUMINANCE := 0.2
const TINT_MARK_FILL := Color(1, 1, 1)
const SHADE_MARK_FILL := Color(0, 0, 0)

var symbol: StringName = &"":
	set(value):
		symbol = value
		queue_redraw()
var fill: Color = Color.WHITE:
	set(value):
		fill = value
		queue_redraw()
var mark: ColorDef.SymbolMark = ColorDef.SymbolMark.NONE:
	set(value):
		mark = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(28, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(color: ColorDef) -> ColorSymbol:
	symbol = color.symbol
	fill = color.display_color
	mark = color.symbol_mark
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
	draw_polyline(closed, ColorSymbol.outline_color(fill), OUTLINE_WIDTH, true)
	if mark != ColorDef.SymbolMark.NONE:
		var dot := ColorSymbol.mark_dot(mark, box)
		var dot_fill := ColorSymbol.mark_fill(mark)
		draw_circle(dot.get_center(), dot.size.x / 2.0, dot_fill)
		draw_circle(dot.get_center(), dot.size.x / 2.0, ColorSymbol.outline_color(dot_fill), false,
			OUTLINE_WIDTH * 0.75, true)


## The outline color for a shape filled with [param p_fill]: dark, or light
## for a dark fill.
static func outline_color(p_fill: Color) -> Color:
	return LIGHT_OUTLINE_COLOR if p_fill.get_luminance() < DARK_FILL_LUMINANCE else OUTLINE_COLOR


## The box of the dot of [param p_mark] on a symbol in [param box]: at the top
## right for a tint, and at the bottom right for a shade, so that the two
## marks differ by place and not only by color. Empty for no mark.
static func mark_dot(p_mark: ColorDef.SymbolMark, box: Rect2) -> Rect2:
	var side := box.size.x * 0.42
	match p_mark:
		ColorDef.SymbolMark.TINT:
			return Rect2(Vector2(box.end.x - side, box.position.y), Vector2(side, side))
		ColorDef.SymbolMark.SHADE:
			return Rect2(box.end - Vector2(side, side), Vector2(side, side))
	return Rect2()


static func mark_fill(p_mark: ColorDef.SymbolMark) -> Color:
	return SHADE_MARK_FILL if p_mark == ColorDef.SymbolMark.SHADE else TINT_MARK_FILL


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
		&"diamond":
			return PackedVector2Array([Vector2(c.x, box.position.y), Vector2(box.end.x, c.y),
				Vector2(c.x, box.end.y), Vector2(box.position.x, c.y)])
		&"pentagon":
			return _regular_polygon(c + Vector2(0, r * 0.08), r, 5, -PI / 2.0)
		&"hexagon":
			return _regular_polygon(c, r, 6, 0.0)
		&"star":
			return _star(c + Vector2(0, r * 0.08), r, r * 0.45, 5)
		&"triangle_down":
			return PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), Vector2(c.x, box.end.y)])
		&"trapezoid":
			var top := box.position.y + r * 0.3
			var bottom := box.end.y - r * 0.3
			return PackedVector2Array([Vector2(box.position.x + r * 0.5, top), Vector2(box.end.x - r * 0.5, top),
				Vector2(box.end.x, bottom), Vector2(box.position.x, bottom)])
		&"cross":
			var arm := r * 0.36
			var points := PackedVector2Array()
			for corner: Vector2 in [Vector2(-arm, -r), Vector2(arm, -r), Vector2(arm, -arm), Vector2(r, -arm),
					Vector2(r, arm), Vector2(arm, arm), Vector2(arm, r), Vector2(-arm, r), Vector2(-arm, arm),
					Vector2(-r, arm), Vector2(-r, -arm), Vector2(-arm, -arm)]:
				points.append(c + corner)
			return points
		&"arrow":
			# Points right: a shaft and a head.
			var shaft := r * 0.34
			var points := PackedVector2Array()
			for corner: Vector2 in [Vector2(-r, -shaft), Vector2(0, -shaft), Vector2(0, -r), Vector2(r, 0),
					Vector2(0, r), Vector2(0, shaft), Vector2(-r, shaft)]:
				points.append(c + corner)
			return points
		&"crescent":
			return _crescent(c, r)
		&"heart":
			return _heart(c, r)
		&"octagon":
			return _regular_polygon(c, r, 8, PI / 8.0)
		&"hourglass":
			# Two triangles that meet at a narrow waist.
			var waist := r * 0.16
			var inset := r * 0.1
			return PackedVector2Array([box.position + Vector2(inset, 0), Vector2(box.end.x - inset, box.position.y),
				Vector2(c.x + waist, c.y), box.end - Vector2(inset, 0), Vector2(box.position.x + inset, box.end.y),
				Vector2(c.x - waist, c.y)])
	return PackedVector2Array()


## A star with [param tips] points, the first one up.
static func _star(center: Vector2, outer: float, inner: float, tips: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in tips * 2:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + PI * i / tips
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## A crescent that opens to the right: the outer circle less a smaller circle
## moved to the right. The outline goes along the outer circle, from one point
## where the circles cross to the other, and back along the inner circle.
static func _crescent(center: Vector2, radius: float) -> PackedVector2Array:
	const STEPS := 24
	var shift := radius * 0.5
	var inner_radius := radius * 0.8
	# The circles cross at x = along, y = +-across from the outer center.
	var along := (radius * radius - inner_radius * inner_radius + shift * shift) / (2.0 * shift)
	var across := sqrt(radius * radius - along * along)
	var open := atan2(across, along)
	var points := PackedVector2Array()
	for i in STEPS + 1:
		var angle := open + (TAU - 2.0 * open) * i / STEPS
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var inner_center := center + Vector2(shift, 0)
	var start := atan2(-across, along - shift)
	var end := atan2(across, along - shift) - TAU
	for i in range(1, STEPS):
		var angle := start + (end - start) * i / STEPS
		points.append(inner_center + Vector2(cos(angle), sin(angle)) * inner_radius)
	return points


## A heart, from the classic parametric curve, scaled into the box.
static func _heart(center: Vector2, radius: float) -> PackedVector2Array:
	const STEPS := 48
	var points := PackedVector2Array()
	for i in STEPS:
		var t := TAU * i / STEPS
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		points.append(center + Vector2(x, -y - 2.5) * (radius / 17.0))
	return points


static func _regular_polygon(center: Vector2, radius: float, sides: int, start_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle := start_angle + TAU * i / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
