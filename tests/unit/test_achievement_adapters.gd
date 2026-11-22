extends GutTest
## The platform adapters of achievements (#25) load and fail safely in a build
## with no SDK or plugin, such as the headless test run. They are skeletons
## until a person finishes them on each platform (docs/achievements.md).

var _adapters: Array[Script] = [
	SteamAchievementService,
	GameCenterAchievementService,
	GooglePlayAchievementService,
]


func _def() -> AchievementDef:
	var ids: Dictionary[StringName, String] = {&"steam": "FIRST_SALE", &"game_center": "first_sale",
		&"google_play": "CgkI_test"}
	return AchievementDef.new(&"first_sale", "First sale", "Sell a widget.", Milestones.FIRST_SALE, 1, ids)


func test_each_adapter_with_no_sdk_does_nothing() -> void:
	for adapter in _adapters:
		var service: AchievementService = adapter.new()

		assert_false(service.has_sdk(), adapter.get_global_name())
		assert_false(service.is_available(), adapter.get_global_name())
		assert_false(service.unlock(_def()), adapter.get_global_name())
		service.poll()


func test_each_adapter_has_its_platform_key() -> void:
	var keys: Array[StringName] = []
	for adapter in _adapters:
		keys.append((adapter.new() as AchievementService).platform())

	assert_eq(keys, AchievementDef.PLATFORMS)


func test_this_device_with_no_sdk_gets_the_test_adapter() -> void:
	var service := AchievementServices.for_this_device()

	assert_true(service is TestAchievementService)
	assert_true(service.is_available())


func test_the_test_adapter_keeps_each_unlock_once() -> void:
	var service := TestAchievementService.new()

	assert_true(service.unlock(_def()))
	assert_true(service.unlock(_def()))

	assert_eq(service.unlocked, [&"first_sale"] as Array[StringName])


func test_the_test_adapter_takes_nothing_while_it_is_not_available() -> void:
	var service := TestAchievementService.new()
	service.available = false
	watch_signals(service)

	assert_false(service.unlock(_def()))
	service.available = true

	assert_eq(service.unlocked, [] as Array[StringName])
	assert_signal_emit_count(service, "became_available", 1)
