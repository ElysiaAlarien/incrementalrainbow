extends GutTest
## [GooglePlayCloudSave] with a fake of the Android singleton of
## godot-play-game-services v3.4.0. The fake has the method and signal names
## of the plugin (GodotAndroidPlugin.kt, signals/Signals.kt). It answers only
## when a test emits a signal, as the plugin answers later.


## The parts of the plugin singleton that the adapter uses.
class FakePlayGames:
	extends RefCounted

	signal userAuthenticated(is_authenticated: bool)
	signal gameLoaded(json_data: String)
	signal gameSaved(is_saved: bool, save_data_name: String, description: String)
	signal conflictEmitted(json_data: String)

	var calls: Array[String] = []
	var last_save: Array = []

	func initialize() -> void:
		calls.append("initialize")

	func isAuthenticated() -> void:
		calls.append("isAuthenticated")

	func loadGame(file_name: String, create_if_not_found: bool) -> void:
		calls.append("loadGame %s %s" % [file_name, create_if_not_found])

	func saveGame(file_name: String, description: String, save_data: PackedByteArray,
			played_time_millis: int, progress_value: int) -> void:
		calls.append("saveGame %s" % file_name)
		last_save = [file_name, description, save_data, played_time_millis, progress_value]


var _play: FakePlayGames
var _cloud: GooglePlayCloudSave
var _now := "2026-11-22 10:00:00"


func before_each() -> void:
	_play = FakePlayGames.new()
	_cloud = GooglePlayCloudSave.new(_play)
	_cloud.clock = func() -> String: return _now


func _sign_in() -> void:
	_play.userAuthenticated.emit(true)


## The JSON of gameLoaded for a snapshot with [param text], as Gson writes it:
## the content is an array of signed bytes.
func _snapshot_json(text: String, unique_name: String = CloudSave.SAVE_NAME) -> String:
	var content: Array[int] = []
	for byte in text.to_utf8_buffer():
		content.append(byte - 256 if byte > 127 else byte)
	return JSON.stringify({
		"content": content,
		"metadata": {"uniqueName": unique_name, "description": "Incremental Rainbow", "playedTime": 0},
	})


func test_the_adapter_asks_for_the_sign_in_and_does_not_initialize_the_plugin() -> void:
	assert_eq(_play.calls, ["isAuthenticated"] as Array[String], "PlatformSdks initializes the plugin, once")


func test_a_signed_in_player_has_google_play() -> void:
	assert_false(_cloud.is_available(), "no answer yet")

	_sign_in()

	assert_true(_cloud.is_available())


func test_a_read_before_the_sign_in_answer_waits_for_it() -> void:
	var read := _cloud.read()
	assert_false(read.is_done())
	assert_false(_play.calls.has("loadGame %s false" % CloudSave.SAVE_NAME))

	_sign_in()
	_play.gameLoaded.emit(_snapshot_json("a save"))

	assert_true(read.is_ok())
	assert_eq(read.text, "a save")


func test_a_write_before_the_sign_in_answer_waits_for_it() -> void:
	var written := _cloud.write("a save")
	assert_false(written.is_done())

	_sign_in()
	_play.gameSaved.emit(true, CloudSave.SAVE_NAME, _play.last_save[1])

	assert_true(written.is_ok())


func test_a_player_who_is_not_signed_in_has_no_google_play() -> void:
	var waiting := _cloud.read()

	_play.userAuthenticated.emit(false)

	assert_eq(waiting.status, CloudOperation.Status.NOT_AVAILABLE)
	assert_string_contains(waiting.message, "not signed in")
	assert_false(_cloud.is_available())


func test_an_operation_while_signed_out_asks_again_for_the_sign_in() -> void:
	_play.userAuthenticated.emit(false)
	_play.calls.clear()

	var read := _cloud.read()
	var written := _cloud.write("text")

	assert_eq(_play.calls, ["isAuthenticated"] as Array[String], "one question for both")
	assert_false(read.is_done())
	_play.userAuthenticated.emit(false)
	assert_eq(read.status, CloudOperation.Status.NOT_AVAILABLE)
	assert_eq(written.status, CloudOperation.Status.NOT_AVAILABLE)


func test_a_sign_in_after_the_start_works_at_the_next_operation() -> void:
	_play.userAuthenticated.emit(false)

	var read := _cloud.read()
	_sign_in()
	_play.gameLoaded.emit(_snapshot_json("a save"))

	assert_eq(read.text, "a save")


func test_a_later_sign_in_makes_google_play_available() -> void:
	_play.userAuthenticated.emit(false)

	_sign_in()

	assert_true(_cloud.is_available())


func test_an_operation_that_timed_out_before_the_sign_in_does_not_start_later() -> void:
	var read := await _cloud.read().wait(0.02)
	assert_eq(read.status, CloudOperation.Status.FAILED)

	_sign_in()

	assert_false(_play.calls.has("loadGame %s false" % CloudSave.SAVE_NAME))


func test_a_read_gets_the_text_of_the_snapshot_with_all_bytes() -> void:
	_sign_in()
	var text := "Zm9v ünïcode ✓"

	var read := _cloud.read()
	assert_true(_play.calls.has("loadGame %s false" % CloudSave.SAVE_NAME), "does not make a snapshot")
	_play.gameLoaded.emit(_snapshot_json(text))

	assert_true(read.is_ok())
	assert_eq(read.text, text)


func test_a_cloud_with_no_snapshot_reads_as_an_empty_text() -> void:
	_sign_in()

	var read := _cloud.read()
	# The plugin sends Gson().toJson(null) when it finds no snapshot.
	_play.gameLoaded.emit("null")

	assert_true(read.is_ok())
	assert_eq(read.text, "")


func test_a_snapshot_of_another_name_is_not_the_answer() -> void:
	_sign_in()

	var read := _cloud.read()
	_play.gameLoaded.emit(_snapshot_json("other", "another_save"))

	assert_false(read.is_done())


func test_a_snapshot_that_is_not_valid_json_fails_the_read() -> void:
	_sign_in()

	var read := _cloud.read()
	_play.gameLoaded.emit("{not json")

	assert_eq(read.status, CloudOperation.Status.FAILED)


func test_a_write_saves_the_text_as_the_snapshot_with_the_save_time() -> void:
	_sign_in()

	var written := _cloud.write("a save")

	assert_eq(_play.last_save[0], CloudSave.SAVE_NAME)
	assert_eq(_play.last_save[1], "Incremental Rainbow, saved 2026-11-22 10:00:00")
	assert_eq((_play.last_save[2] as PackedByteArray).get_string_from_utf8(), "a save")
	assert_eq(_play.last_save.slice(3), [0, 0])
	assert_false(written.is_done())
	_play.gameSaved.emit(true, CloudSave.SAVE_NAME, _play.last_save[1])
	assert_true(written.is_ok())


func test_a_write_with_no_answer_fails_at_the_timeout() -> void:
	_sign_in()

	var written := await _cloud.write("a save").wait(0.02)

	assert_eq(written.status, CloudOperation.Status.FAILED)


func test_a_late_answer_of_an_earlier_write_does_not_finish_the_next_write() -> void:
	_sign_in()
	var first := await _cloud.write("first").wait(0.02)
	var first_description: String = _play.last_save[1]
	_now = "2026-11-22 10:05:00"

	var second := _cloud.write("second")
	_play.gameSaved.emit(true, CloudSave.SAVE_NAME, first_description)

	assert_eq(first.status, CloudOperation.Status.FAILED)
	assert_false(second.is_done())
	_play.gameSaved.emit(true, CloudSave.SAVE_NAME, _play.last_save[1])
	assert_true(second.is_ok())


func test_a_write_that_the_plugin_did_not_save_fails() -> void:
	_sign_in()

	var written := _cloud.write("a save")
	_play.gameSaved.emit(false, CloudSave.SAVE_NAME, _play.last_save[1])

	assert_eq(written.status, CloudOperation.Status.FAILED)


func test_a_conflict_fails_only_the_operation_that_found_it() -> void:
	_sign_in()
	var read := _cloud.read()
	var written := _cloud.write("a save")

	_play.conflictEmitted.emit(JSON.stringify({"origin": "SAVE", "conflictId": "c1"}))

	assert_eq(written.status, CloudOperation.Status.FAILED)
	assert_false(read.is_done())
	_play.conflictEmitted.emit(JSON.stringify({"origin": "LOAD", "conflictId": "c2"}))
	assert_eq(read.status, CloudOperation.Status.FAILED)


func test_one_read_at_a_time() -> void:
	_sign_in()
	var first := _cloud.read()

	var second := _cloud.read()

	assert_false(first.is_done())
	assert_eq(second.status, CloudOperation.Status.FAILED)


func test_the_first_sync_of_a_start_waits_for_the_sign_in_then_uploads() -> void:
	var save_path := "user://test_google_play_session_save.json"
	var content := ContentFixture.make_for_saves()
	var local := ExportCode.encode(Simulation.new(content, 5), 1_795_000_000_000)
	var session := CloudSaveSession.new(_cloud, content, save_path)
	var plans: Array[CloudSyncPlan] = []
	session.synced.connect(func(plan: CloudSyncPlan) -> void: plans.append(plan))

	session.sync(local, 1_795_000_000_000, true)
	await get_tree().process_frame
	_sign_in()
	await get_tree().process_frame
	_play.gameLoaded.emit("null")
	await get_tree().process_frame
	assert_eq((_play.last_save[2] as PackedByteArray).get_string_from_utf8(), local)
	_play.gameSaved.emit(true, CloudSave.SAVE_NAME, _play.last_save[1])
	await get_tree().process_frame

	assert_eq(plans.size(), 1)
	assert_eq(plans[0].action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(plans[0].notice, CloudSyncPlan.Notice.NONE)
	assert_false(session.is_busy())
	DirAccess.remove_absolute(save_path + CloudSyncRecord.SUFFIX)
