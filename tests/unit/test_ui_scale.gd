extends GutTest
## UiScale sets how many device pixels one logical pixel uses, so that the
## layout fits each screen and touch targets have a useful physical size.


func test_a_phone_uses_one_logical_pixel_for_each_160th_of_an_inch() -> void:
	assert_almost_eq(UiScale.device_density(Vector2(2400, 1080), 400, 1.0, true), 2.5, 0.001)
	assert_almost_eq(UiScale.factor(Vector2(2400, 1080), 2.5), 2.5, 0.001)
	assert_eq(UiScale.logical_size(Vector2(2400, 1080), 2.5), Vector2(960, 432))


func test_a_computer_uses_the_scale_of_its_operating_system() -> void:
	assert_eq(UiScale.device_density(Vector2(1920, 1080), 96, 1.0, false), 1.0)
	assert_eq(UiScale.device_density(Vector2(2880, 1800), 220, 2.0, false), 2.0)


func test_a_computer_scales_up_a_tall_window_that_its_operating_system_does_not_scale() -> void:
	assert_almost_eq(UiScale.device_density(Vector2(2560, 1440), 109, 1.0, false), 1440.0 / 1080.0, 0.001)
	assert_eq(UiScale.device_density(Vector2(1280, 720), 96, 1.0, false), 1.0, "a small window is not scaled down")


func test_a_small_screen_scales_down_to_keep_the_minimum_logical_size() -> void:
	var scale := UiScale.factor(Vector2(1280, 600), 2.5)
	assert_almost_eq(scale, 600.0 / UiScale.MIN_LOGICAL_SIZE.y, 0.001)
	var size := UiScale.logical_size(Vector2(1280, 600), scale)
	assert_gte(size.x, UiScale.MIN_LOGICAL_SIZE.x)
	assert_gte(size.y, UiScale.MIN_LOGICAL_SIZE.y)


func test_each_device_has_at_least_the_minimum_logical_size() -> void:
	for profile in DeviceProfiles.all():
		var size := profile.logical_size()
		assert_gte(size.x, UiScale.MIN_LOGICAL_SIZE.x, profile.name)
		assert_gte(size.y, UiScale.MIN_LOGICAL_SIZE.y, profile.name)


func test_a_touch_target_is_about_7_mm_on_each_phone_and_tablet() -> void:
	for profile in DeviceProfiles.all():
		if profile.mobile:
			assert_almost_eq(profile.millimeters(UiScale.MIN_TOUCH_TARGET), 7.0, 0.2, profile.name)


func test_the_safe_area_moves_the_margins_away_from_a_notch() -> void:
	var window := Rect2(0, 0, 2400, 1080)
	# A notch on the left in landscape takes 100 device pixels.
	var margins := UiScale.safe_margins(window, Rect2(100, 0, 2300, 1080), 2.5, 12)
	assert_eq(margins, Vector4(40, 12, 12, 12))


func test_a_safe_area_that_is_the_whole_screen_keeps_the_base_margins() -> void:
	var window := Rect2(0, 0, 1920, 1080)
	assert_eq(UiScale.safe_margins(window, window, 1.0, 12), Vector4(12, 12, 12, 12))
	assert_eq(UiScale.safe_margins(window, Rect2(), 1.0, 12), Vector4(12, 12, 12, 12), "no safe area")
