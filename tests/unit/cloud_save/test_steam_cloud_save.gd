extends GutTest
## [SteamCloudSave] with a fake of the GodotSteam singleton. The fake has the
## method names and return values of GodotSteam v4.24 (godotsteam.cpp).


## The parts of the GodotSteam singleton that the adapter uses.
class FakeSteam:
	extends RefCounted

	var init_result := {"status": 0, "verbal": "Steamworks active."}
	var cloud_for_account := true
	var cloud_for_app := true
	var files := {}
	## When not null, the next fileRead returns this in place of the file.
	var next_read: Variant = null
	var write_works := true
	var remote_storage_calls := 0

	func get_steam_init_result() -> Dictionary:
		return init_result

	func isCloudEnabledForAccount() -> bool:
		remote_storage_calls += 1
		return cloud_for_account

	func isCloudEnabledForApp() -> bool:
		remote_storage_calls += 1
		return cloud_for_app

	func fileExists(file: String) -> bool:
		remote_storage_calls += 1
		return files.has(file)

	func getFileSize(file: String) -> int:
		remote_storage_calls += 1
		return (files[file] as PackedByteArray).size() if files.has(file) else 0

	func fileRead(file: String, data_to_read: int) -> Dictionary:
		remote_storage_calls += 1
		if next_read != null:
			return next_read
		var data: PackedByteArray = files.get(file, PackedByteArray())
		var buf := data.slice(0, data_to_read)
		buf.resize(data_to_read)
		return {"ret": mini(data.size(), data_to_read), "buf": buf}

	func fileWrite(file: String, data: PackedByteArray, _size: int = 0) -> bool:
		remote_storage_calls += 1
		if write_works:
			files[file] = data
		return write_works


var _steam: FakeSteam
var _cloud: SteamCloudSave


func before_each() -> void:
	_steam = FakeSteam.new()
	_cloud = SteamCloudSave.new(_steam)


func test_a_started_steam_with_cloud_on_is_available() -> void:
	assert_true(_cloud.is_available())


func test_a_steam_that_did_not_start_is_not_available_and_is_not_called() -> void:
	for result: Dictionary in [{}, {"status": 2, "verbal": "Steam is not running."}]:
		_steam.init_result = result
		_steam.remote_storage_calls = 0

		assert_false(_cloud.is_available(), str(result))
		assert_eq(_cloud.read().status, CloudOperation.Status.NOT_AVAILABLE, str(result))
		assert_eq(_cloud.write("text").status, CloudOperation.Status.NOT_AVAILABLE, str(result))
		assert_eq(_steam.remote_storage_calls, 0, "each Remote Storage call logs an error before a start")


func test_steam_cloud_off_for_the_account_or_the_game_is_not_available() -> void:
	_steam.cloud_for_account = false
	assert_false(_cloud.is_available())
	var read := _cloud.read()
	assert_eq(read.status, CloudOperation.Status.NOT_AVAILABLE)
	assert_string_contains(read.message, "off")

	_steam.cloud_for_account = true
	_steam.cloud_for_app = false
	assert_false(_cloud.is_available())


func test_a_write_then_a_read_gives_the_same_text() -> void:
	var text := "eJzLSM3JyVcozy/KSQEAGgQEXQ==  ünïcode"

	var written := _cloud.write(text)
	var read := _cloud.read()

	assert_true(written.is_ok())
	assert_true(read.is_ok())
	assert_eq(read.text, text)
	assert_true(_steam.files.has(CloudSave.SAVE_NAME))


func test_a_cloud_with_no_save_reads_as_an_empty_text() -> void:
	var read := _cloud.read()

	assert_true(read.is_ok())
	assert_eq(read.text, "")


func test_an_empty_save_file_reads_as_no_save() -> void:
	_steam.files[CloudSave.SAVE_NAME] = PackedByteArray()

	var read := _cloud.read()

	assert_true(read.is_ok())
	assert_eq(read.text, "")


func test_a_read_that_steam_cannot_do_fails() -> void:
	_steam.files[CloudSave.SAVE_NAME] = "a save".to_utf8_buffer()
	# GodotSteam sets "ret" to false when it has no Remote Storage.
	for answer: Dictionary in [{"ret": false}, {"ret": 2, "buf": PackedByteArray([1, 2])}, {}]:
		_steam.next_read = answer

		var read := _cloud.read()

		assert_eq(read.status, CloudOperation.Status.FAILED, str(answer))


func test_a_write_that_steam_refuses_fails_and_keeps_the_old_save() -> void:
	_cloud.write("old")
	_steam.write_works = false

	var written := _cloud.write("new")

	assert_eq(written.status, CloudOperation.Status.FAILED)
	assert_eq(_cloud.read().text, "old")
