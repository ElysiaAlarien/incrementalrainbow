extends GutTest
## Smoke tests: the main screen syncs its save with a cloud save, with the
## test adapter as the cloud (ADR-0018).

const MainScene := preload("res://src/ui/main.tscn")
const SAVE_PATH := "user://test_saves/cloud_screen.json"
## The device clock at the start of each test: a time in November 2026.
const NOW_MS := 1_795_000_000_000

var _now_ms := NOW_MS
var _cloud: TestCloudSave
var _content: Content


func before_each() -> void:
	_now_ms = NOW_MS
	_cloud = TestCloudSave.new()
	_content = Content.load_dir(Content.DEFAULT_DIR)
	for suffix in ["", SaveFile.DAMAGED_SUFFIX, SaveFile.TEMP_SUFFIX, CloudSyncRecord.SUFFIX,
			CloudSaveSession.KEPT_SUFFIX]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(SAVE_PATH + suffix)


func after_all() -> void:
	before_each()


func _open_main() -> Control:
	var main: Control = MainScene.instantiate()
	main.save_path = SAVE_PATH
	main.clock = func() -> int: return _now_ms
	main.cloud_save = _cloud
	add_child_autofree(main)
	await wait_process_frames(2)
	return main


## The export code of a game with [param factories] red factories, saved at
## [param saved_at_unix_ms], as from another device.
func _other_device_code(factories: int, saved_at_unix_ms: int) -> String:
	var sim := Simulation.new(_content, 9)
	for i in factories:
		sim.build_factory(&"red")
	return ExportCode.encode(sim, saved_at_unix_ms)


func _message(main: Control) -> String:
	return (main.find_child("MessageLabel", true, false) as Label).text


func _cloud_game() -> LoadResult:
	return ExportCode.decode(_content, _cloud.stored_text())


## Plays a game on this device, quits, and comes back to [param main] later.
func _game_played_here(factories: int) -> void:
	var main := await _open_main()
	for i in factories:
		main.simulation().build_factory(&"red")
	main.queue_free()
	await wait_process_frames(1)


func test_a_new_game_with_an_empty_cloud_uploads_it() -> void:
	var main := await _open_main()

	assert_eq(_cloud.writes, 1)
	assert_true(_cloud_game().ok)
	assert_eq(_message(main), "")


func test_a_new_install_loads_the_cloud_save_and_tells_the_player() -> void:
	_cloud.put(_other_device_code(3, NOW_MS - 60_000))

	var main := await _open_main()

	assert_eq(main.simulation().factories().size(), 3)
	assert_string_contains(_message(main), "Your game loaded from test cloud save")
	assert_true(FileAccess.file_exists(SAVE_PATH), "the cloud game is saved on the device")
	assert_eq(_cloud.writes, 0, "the cloud save is not overwritten")


func test_quitting_uploads_the_game() -> void:
	var main := await _open_main()
	main.simulation().build_factory(&"red")

	main.queue_free()
	await wait_process_frames(1)

	assert_eq(_cloud_game().simulation.factories().size(), 1)


func test_play_on_another_device_comes_here_at_the_next_start() -> void:
	await _game_played_here(1)
	_cloud.put(_other_device_code(4, NOW_MS + 60_000))
	_now_ms += 120_000

	var main := await _open_main()

	assert_eq(main.simulation().factories().size(), 4)
	assert_string_contains(_message(main), "Your game loaded from")
	assert_false((main.find_child("CloudSaveDialog", true, false) as Window).visible, "no conflict")


func test_play_on_both_devices_uses_the_save_from_last_and_tells_the_player() -> void:
	await _game_played_here(1)
	# The game on this device saved again, after the last sync.
	var save := SaveCodec.decode(_content, FileAccess.get_file_as_string(SAVE_PATH))
	save.simulation.build_factory(&"red")
	SaveFile.new(SAVE_PATH).write(SaveCodec.encode(save.simulation, NOW_MS + 10_000))
	_cloud.put(_other_device_code(5, NOW_MS + 60_000))
	_now_ms += 120_000

	var main := await _open_main()

	assert_eq(main.simulation().factories().size(), 5, "the cloud save saved last")
	var dialog: CloudSaveDialog = main.find_child("CloudSaveDialog", true, false)
	var summary: OfflineSummaryDialog = main.find_child("OfflineSummaryDialog", true, false)
	await wait_until(func() -> bool: return summary.visible, 5.0)
	assert_false(dialog.visible, "one dialog at a time: the summary of the time away first")
	summary.hide()
	assert_true(dialog.visible)
	assert_string_contains(dialog.text(), "The game uses the one that saved last: the game in test cloud save")

	dialog.find_child("UseOtherSave", true, false).pressed.emit()
	await wait_process_frames(2)

	assert_eq(main.simulation().factories().size(), 2, "the player changed to the game on this device")
	assert_false(dialog.visible)
	assert_eq(_cloud_game().simulation.factories().size(), 2, "the choice goes to the cloud")
	assert_eq(ExportCode.decode(_content, FileAccess.get_file_as_string(SAVE_PATH + CloudSaveSession.KEPT_SUFFIX)) \
		.simulation.factories().size(), 5, "the cloud game is kept")


func test_a_phone_back_from_the_background_gets_play_from_another_device() -> void:
	var main := await _open_main()
	main.simulation().build_factory(&"red")
	main.notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_cloud_game().simulation.factories().size(), 1, "the background uploads")
	_cloud.put(_other_device_code(3, NOW_MS + 60_000))
	_now_ms += 120_000

	main.notification(NOTIFICATION_APPLICATION_RESUMED)
	await wait_process_frames(2)

	assert_eq(main.simulation().factories().size(), 3)
	assert_string_contains(_message(main), "Your game loaded from")


func test_a_cloud_save_of_a_newer_game_is_not_overwritten() -> void:
	var data := JSON.parse_string(SaveCodec.encode(Simulation.new(_content, 1), NOW_MS)) as Dictionary
	data.applied.append("a_change_of_a_newer_game")
	var newer := ExportCode.from_save(JSON.stringify(data), SaveCodec.VERSION)
	_cloud.put(newer)

	var main := await _open_main()
	var message := _message(main)
	main.simulation().build_factory(&"red")
	main.queue_free()
	await wait_process_frames(1)

	assert_string_contains(message, "A newer version of the game saved your game in test cloud save")
	assert_eq(_cloud.stored_text(), newer)
	assert_eq(_cloud.writes, 0)


func test_a_cloud_that_does_not_answer_lets_the_game_play_and_tells_the_player() -> void:
	_cloud.fail_next_read = "No network."

	var main := await _open_main()

	assert_string_contains(_message(main), "could not reach test cloud save")
	assert_string_contains(_message(main), "No network.")
	assert_true(main.simulation().build_factory(&"red").ok)


func test_a_cloud_that_answers_later_does_not_stop_the_game() -> void:
	_cloud.hold_answers = true
	_cloud.put(_other_device_code(2, NOW_MS - 60_000))

	var main := await _open_main()
	assert_eq(main.simulation().factories().size(), 0, "the game plays while it waits")
	_cloud.hold_answers = false
	_cloud.answer_held()
	await wait_process_frames(1)

	assert_eq(main.simulation().factories().size(), 2)


func test_with_no_cloud_the_game_saves_only_on_the_device() -> void:
	_cloud.available = false

	var main := await _open_main()
	var message := _message(main)
	main.simulation().build_factory(&"red")
	main.queue_free()
	await wait_process_frames(1)

	assert_eq(_cloud.stored_text(), "")
	assert_true(FileAccess.file_exists(SAVE_PATH))
	assert_eq(message, "")
