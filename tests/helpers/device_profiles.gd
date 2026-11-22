class_name DeviceProfiles
extends RefCounted
## Screens of real devices, for the layout tests: phones, tablets, and
## computers, all in landscape. Each has its size in device pixels, its dots
## per inch, the scale of its operating system, and whether it is a phone or a
## tablet.


## One device.
class Profile:
	extends RefCounted
	var name: String
	var window_px: Vector2
	var dpi: float
	var os_scale: float
	var mobile: bool

	func _init(p_name: String, p_window_px: Vector2, p_dpi: float, p_os_scale: float, p_mobile: bool) -> void:
		name = p_name
		window_px = p_window_px
		dpi = p_dpi
		os_scale = p_os_scale
		mobile = p_mobile

	## The scale that [UiScale] gives this device.
	func scale() -> float:
		return UiScale.factor(window_px, UiScale.device_density(window_px, dpi, os_scale, mobile))

	## The logical size of the screen at [method scale].
	func logical_size() -> Vector2:
		return UiScale.logical_size(window_px, scale())

	## [param logical] pixels in millimeters on this screen.
	func millimeters(logical: float) -> float:
		return logical * scale() / dpi * 25.4


static func all() -> Array[Profile]:
	return [
		# A small phone with a 16:9 screen, such as an iPhone SE.
		Profile.new("small phone", Vector2(1334, 750), 326, 2.0, true),
		# A phone with a 20:9 screen.
		Profile.new("phone", Vector2(2400, 1080), 400, 1.0, true),
		# A large phone with a 19.5:9 screen.
		Profile.new("large phone", Vector2(2796, 1290), 460, 3.0, true),
		# A tablet with a 4:3 screen, such as an iPad.
		Profile.new("4:3 tablet", Vector2(2048, 1536), 264, 2.0, true),
		# A tablet with a 16:10 screen.
		Profile.new("16:10 tablet", Vector2(2560, 1600), 320, 1.0, true),
		# A small window on a computer.
		Profile.new("720p window", Vector2(1280, 720), 96, 1.0, false),
		Profile.new("1080p monitor", Vector2(1920, 1080), 96, 1.0, false),
		# A laptop with the 150% scale of Windows.
		Profile.new("1080p laptop at 150%", Vector2(1920, 1080), 144, 1.5, false),
		Profile.new("1440p monitor", Vector2(2560, 1440), 109, 1.0, false),
		Profile.new("4K monitor at 200%", Vector2(3840, 2160), 192, 2.0, false),
		Profile.new("ultrawide monitor", Vector2(3440, 1440), 110, 1.0, false),
	]


## The profile of [method all] with [param name].
static func named(name: String) -> Profile:
	for profile in all():
		if profile.name == name:
			return profile
	assert(false, "No device profile %s" % name)
	return null
