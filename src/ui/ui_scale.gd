class_name UiScale
extends RefCounted
## The scale of the screen: how many device pixels one logical pixel of the
## layout uses. The layout uses logical pixels, so the same layout fits a small
## phone and a large monitor, and text and touch targets have a useful
## physical size on each.
##
## - On a phone or a tablet, one logical pixel is one Android "dp": 1/160 of an
##   inch. So a touch target of [constant MIN_TOUCH_TARGET] logical pixels is
##   about 7 mm on all phones and tablets.
## - On a computer, the scale is the scale of the operating system (2 on a Mac
##   Retina screen, 1.5 for 150% on Windows), but at least the window height over
##   [constant DESKTOP_REFERENCE_HEIGHT]. Thus the game does not look small in
##   a large window on a monitor that the operating system does not scale.
## - The logical size is never smaller than [constant MIN_LOGICAL_SIZE]. On a
##   smaller screen, the scale goes down to fit the layout.
##
## The functions are pure, so that tests can give the values of any device.
## [method apply] reads the device and sets the scale of a window.

## The smallest logical size of the screen. The layout must fit it.
const MIN_LOGICAL_SIZE := Vector2(640, 360)
## The dots per inch of one logical pixel on a phone or a tablet.
const MOBILE_REFERENCE_DPI := 160.0
## The DPI of a Windows screen at a scale of 100%.
const WINDOWS_REFERENCE_DPI := 96.0
## The window height, in device pixels, at which a computer uses a scale of 1
## when the operating system does not scale.
const DESKTOP_REFERENCE_HEIGHT := 1080.0
## The smallest width and height of a control that the player presses, in
## logical pixels. 44 dp is about 7 mm on a phone, the size that the Apple and
## WCAG guidelines give for a touch target.
const MIN_TOUCH_TARGET := 44.0


## The logical pixels per inch of the device: the scale that the device asks
## for, before [constant MIN_LOGICAL_SIZE] limits it. [param window_px] is the
## window size in device pixels, [param dpi] the dots per inch of the screen,
## [param os_scale] the scale of the operating system, and [param mobile]
## whether the device is a phone or a tablet.
static func device_density(window_px: Vector2, dpi: float, os_scale: float, mobile: bool) -> float:
	if mobile:
		return maxf(dpi, 1.0) / MOBILE_REFERENCE_DPI
	return maxf(maxf(os_scale, 1.0), window_px.y / DESKTOP_REFERENCE_HEIGHT)


## The scale for a window of [param window_px] device pixels on a device of
## [param density] (see [method device_density]): the density, but no more
## than what keeps the logical size at least [constant MIN_LOGICAL_SIZE].
static func factor(window_px: Vector2, density: float) -> float:
	var fit := minf(window_px.x / MIN_LOGICAL_SIZE.x, window_px.y / MIN_LOGICAL_SIZE.y)
	return maxf(minf(density, fit), 0.01)


## The logical size of a window of [param window_px] device pixels at the
## scale [param scale].
static func logical_size(window_px: Vector2, scale: float) -> Vector2:
	return (window_px / scale).floor()


## The margins, in logical pixels, that keep the layout inside the safe area
## of the screen, such as away from a notch or rounded corners. Each is
## [param base] or more. [param window] and [param safe_area] are in device
## pixels. Returns left, top, right, and bottom.
static func safe_margins(window: Rect2, safe_area: Rect2, scale: float, base: float) -> Vector4:
	var inside := window.intersection(safe_area)
	if not inside.has_area():
		return Vector4(base, base, base, base)
	var left := (inside.position.x - window.position.x) / scale
	var top := (inside.position.y - window.position.y) / scale
	var right := (window.end.x - inside.end.x) / scale
	var bottom := (window.end.y - inside.end.y) / scale
	return Vector4(maxf(base, ceilf(left)), maxf(base, ceilf(top)), maxf(base, ceilf(right)),
		maxf(base, ceilf(bottom)))


## The scale of the operating system for a screen of [param dpi]. Godot does
## not give it on Windows, but there the DPI is the scale that the user set,
## times [constant WINDOWS_REFERENCE_DPI].
static func os_scale(dpi: int) -> float:
	if OS.get_name() == "Windows":
		return dpi / WINDOWS_REFERENCE_DPI
	return DisplayServer.screen_get_scale()


## Whether this device is a phone or a tablet, also for a web build that runs
## in the browser of a phone or a tablet.
static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Sets the scale of [param window] for its current size on this device.
## Returns the scale.
static func apply(window: Window) -> float:
	var screen := window.current_screen
	var window_px := Vector2(window.size)
	var dpi := DisplayServer.screen_get_dpi(screen)
	var density := device_density(window_px, dpi, os_scale(dpi), is_mobile())
	var scale := factor(window_px, density)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i.ZERO
	if not is_equal_approx(window.content_scale_factor, scale):
		window.content_scale_factor = scale
	return scale
