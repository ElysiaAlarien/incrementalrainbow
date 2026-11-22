extends GutTest
## The platform adapters of achievements (#25). Each adapter gets its SDK or
## plugin as an object, so these tests give it a fake with the names of the
## plugin source (docs/achievements.md has the versions). The fakes show that
## an adapter calls the plugin as the source says. They cannot show that the
## plugin does what its source says on a device: that is the smoke test.

var _adapters: Array[Script] = [
	SteamAchievementService,
	GameCenterAchievementService,
	GooglePlayAchievementService,
]


## GodotSteam 4.24: the "Steam" engine singleton.
class FakeSteam:
	extends RefCounted
	var init_status := 0
	var init_calls: Array = []
	var set_achievement_result := true
	var achievements: Array[String] = []
	var stores := 0
	var callback_runs := 0
	## The result of a start before the adapter's, as GodotSteam keeps it.
	var started_result := {}

	func get_steam_init_result() -> Dictionary:
		return started_result

	func steamInitEx(app_id: int = 0, embed_callbacks: bool = false) -> Dictionary:
		init_calls.append([app_id, embed_callbacks])
		return {"status": init_status, "verbal": ""}

	func setAchievement(achievement_name: String) -> bool:
		if set_achievement_result:
			achievements.append(achievement_name)
		return set_achievement_result

	func storeStats() -> bool:
		stores += 1
		return true

	func run_callbacks() -> void:
		callback_runs += 1


## godot-play-game-services 3.4.0: the "GodotPlayGameServices" singleton.
class FakePlayGames:
	extends RefCounted
	signal userAuthenticated(is_authenticated: bool)
	signal achievementUnlocked(is_unlocked: bool, achievement_id: String)
	var initialize_calls := 0
	var authentication_checks := 0
	var unlocked: Array[String] = []

	func initialize() -> void:
		initialize_calls += 1

	func isAuthenticated() -> void:
		authentication_checks += 1

	func unlockAchievement(achievement_id: String) -> void:
		unlocked.append(achievement_id)


## [GameKit] with no plugin: it keeps each report and answers when told.
class FakeGameKit:
	extends GameKit
	var authentications := 0
	var reports: Array[String] = []
	var answers: Array[Callable] = []

	func authenticate() -> void:
		authentications += 1

	func report(achievement_id: String, done: Callable) -> void:
		reports.append(achievement_id)
		answers.append(done)


func _def(ids: Dictionary[StringName, String] = {&"steam": "FIRST_SALE",
		&"game_center": "incrementalrainbow.first_sale", &"google_play": "CgkI_test"}) -> AchievementDef:
	return AchievementDef.new(&"first_sale", "First sale", "Sell a widget.", Milestones.FIRST_SALE, 1, ids)


func _no_ids() -> AchievementDef:
	var ids: Dictionary[StringName, String] = {}
	return _def(ids)


# --- All adapters ---


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


func test_each_platform_with_no_sdk_gets_the_test_adapter() -> void:
	for os_name: String in ["iOS", "Android", "Windows", "macOS", "Linux", "Web"]:
		assert_true(AchievementServices.for_this_device(os_name) is TestAchievementService, os_name)


# --- Steam ---


func test_steam_unlocks_by_its_api_name_and_stores_the_stats() -> void:
	var steam := FakeSteam.new()
	var service := SteamAchievementService.new(steam)

	assert_true(service.has_sdk())
	assert_true(service.is_available())
	assert_true(service.unlock(_def()))

	assert_eq(steam.achievements, ["FIRST_SALE"] as Array[String])
	assert_eq(steam.stores, 1)


func test_steam_does_not_take_an_achievement_that_it_does_not_have() -> void:
	var steam := FakeSteam.new()
	steam.set_achievement_result = false
	var service := SteamAchievementService.new(steam)

	assert_false(service.unlock(_def()))
	assert_eq(steam.stores, 0)


func test_steam_skips_an_achievement_with_no_steam_id() -> void:
	var steam := FakeSteam.new()
	var service := SteamAchievementService.new(steam)

	assert_false(service.unlock(_no_ids()))
	assert_eq(steam.achievements, [] as Array[String])


func test_steam_runs_its_callbacks_at_each_poll() -> void:
	var steam := FakeSteam.new()
	var service := SteamAchievementService.new(steam)

	service.poll()
	service.poll()

	assert_eq(steam.callback_runs, 2)


func test_steam_starts_once_with_embedded_callbacks() -> void:
	var steam := FakeSteam.new()

	assert_true(PlatformSdks.start_steam(steam))

	assert_eq(steam.init_calls, [[0, true]])


func test_steam_that_started_itself_is_not_started_again() -> void:
	var steam := FakeSteam.new()
	steam.started_result = {"status": 0, "verbal": ""}

	assert_true(PlatformSdks.start_steam(steam))

	assert_eq(steam.init_calls, [])


func test_steam_that_did_not_start_itself_is_started() -> void:
	var steam := FakeSteam.new()
	steam.started_result = {"status": 2, "verbal": "No Steam client"}

	assert_true(PlatformSdks.start_steam(steam))

	assert_eq(steam.init_calls, [[0, true]])


func test_steam_that_does_not_start_is_not_used() -> void:
	var steam := FakeSteam.new()
	steam.init_status = 2

	assert_false(PlatformSdks.start_steam(steam))


func test_no_steam_and_no_play_games_in_this_build() -> void:
	assert_null(PlatformSdks.steam())
	assert_null(PlatformSdks.play_games())


# --- Google Play Games ---


func test_play_games_asks_for_the_sign_in_at_start() -> void:
	var play := FakePlayGames.new()
	var service := GooglePlayAchievementService.new(play)

	assert_true(service.has_sdk())
	assert_false(service.is_available())
	assert_eq(play.authentication_checks, 1)
	assert_eq(play.initialize_calls, 0, "PlatformSdks initializes the plugin, once")


func test_play_games_unlocks_nothing_before_the_sign_in() -> void:
	var play := FakePlayGames.new()
	var service := GooglePlayAchievementService.new(play)

	assert_false(service.unlock(_def()))
	assert_eq(play.unlocked, [] as Array[String])


func test_play_games_becomes_available_at_the_sign_in() -> void:
	var play := FakePlayGames.new()
	var service := GooglePlayAchievementService.new(play)
	watch_signals(service)

	play.userAuthenticated.emit(true)
	await wait_process_frames(1)
	play.userAuthenticated.emit(true)
	await wait_process_frames(1)

	assert_true(service.is_available())
	assert_signal_emit_count(service, "became_available", 1)


func test_play_games_stays_unavailable_when_the_sign_in_fails() -> void:
	var play := FakePlayGames.new()
	var service := GooglePlayAchievementService.new(play)
	watch_signals(service)

	play.userAuthenticated.emit(false)
	await wait_process_frames(1)

	assert_false(service.is_available())
	assert_signal_not_emitted(service, "became_available")


func test_play_games_unlocks_by_its_play_console_id() -> void:
	var play := FakePlayGames.new()
	var service := GooglePlayAchievementService.new(play)
	play.userAuthenticated.emit(true)
	await wait_process_frames(1)

	assert_true(service.unlock(_def()))
	assert_false(service.unlock(_no_ids()))

	assert_eq(play.unlocked, ["CgkI_test"] as Array[String])


func test_play_games_logs_an_unlock_that_failed() -> void:
	var play := FakePlayGames.new()
	var service := GooglePlayAchievementService.new(play)
	play.userAuthenticated.emit(true)
	await wait_process_frames(1)
	service.unlock(_def())

	play.achievementUnlocked.emit(false, "CgkI_test")
	await wait_process_frames(1)

	assert_eq(service.failed_unlocks, ["CgkI_test"] as Array[String])


# --- Game Center ---


func test_game_center_authenticates_at_start() -> void:
	var kit := FakeGameKit.new()
	var service := GameCenterAchievementService.new(kit)

	assert_true(service.has_sdk())
	assert_false(service.is_available())
	assert_eq(kit.authentications, 1)


func test_game_center_becomes_available_when_the_player_is_signed_in() -> void:
	var kit := FakeGameKit.new()
	var service := GameCenterAchievementService.new(kit)
	watch_signals(service)

	kit.authentication_result.emit(false)
	await wait_process_frames(1)
	assert_false(service.is_available())
	kit.authentication_result.emit(true)
	await wait_process_frames(1)
	kit.authentication_result.emit(true)
	await wait_process_frames(1)

	assert_true(service.is_available())
	assert_signal_emit_count(service, "became_available", 1)


func test_game_center_is_not_available_after_the_player_signs_out() -> void:
	var kit := FakeGameKit.new()
	var service := GameCenterAchievementService.new(kit)
	kit.authentication_result.emit(true)
	await wait_process_frames(1)

	kit.authentication_result.emit(false)
	await wait_process_frames(1)

	assert_false(service.is_available())
	assert_false(service.unlock(_def()))


func test_game_center_reports_by_its_achievement_id() -> void:
	var kit := FakeGameKit.new()
	var service := GameCenterAchievementService.new(kit)

	assert_false(service.unlock(_def()), "not before the sign-in")
	kit.authentication_result.emit(true)
	await wait_process_frames(1)
	assert_true(service.unlock(_def()))
	assert_false(service.unlock(_no_ids()))

	assert_eq(kit.reports, ["incrementalrainbow.first_sale"] as Array[String])


func test_game_center_logs_a_report_that_failed() -> void:
	var kit := FakeGameKit.new()
	var service := GameCenterAchievementService.new(kit)
	kit.authentication_result.emit(true)
	await wait_process_frames(1)
	service.unlock(_def())
	service.unlock(_def())

	kit.answers[0].call("no network")
	kit.answers[1].call(null)
	await wait_process_frames(1)

	assert_eq(service.failed_unlocks, ["incrementalrainbow.first_sale"] as Array[String])


## The plugin's GameCenterManager, with no device.
class FakeManager:
	extends RefCounted
	signal authentication_result(status: bool)
	signal authentication_error(message: String)
	var authentications := 0

	func authenticate() -> void:
		authentications += 1


func test_game_kit_passes_on_the_sign_in_of_the_manager() -> void:
	var manager := FakeManager.new()
	var kit := GameKit.new(manager)
	watch_signals(kit)

	kit.authenticate()
	manager.authentication_result.emit(true)
	manager.authentication_error.emit("no network")

	assert_eq(manager.authentications, 1)
	assert_signal_emitted_with_parameters(kit, "authentication_result", [true])
	assert_signal_emitted_with_parameters(kit, "authentication_error", ["no network"])


func test_game_kit_is_not_in_this_build() -> void:
	assert_null(GameKit.for_this_build())


# --- Test adapter ---


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
