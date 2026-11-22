extends GutTest
## [ICloudSave] with a fake of the NSUbiquitousKeyValueStore class of
## GodotApplePlugins (Sources/GodotFoundation/NSUbiquitousKeyValueStore.swift,
## commit a66f619).


## The parts of the store that the adapter uses.
class FakeStore:
	extends RefCounted

	var values := {}
	var synchronize_works := true
	var set_works := true
	var synchronized := 0

	func synchronize() -> bool:
		synchronized += 1
		return synchronize_works

	func string_for_key(key: String) -> String:
		return values.get(key, "")

	func set_string(value: String, key: String) -> bool:
		if set_works:
			values[key] = value
		return set_works


var _store: FakeStore
var _cloud: ICloudSave


func before_each() -> void:
	_store = FakeStore.new()
	_cloud = ICloudSave.new(_store)


func test_a_build_with_the_plugin_has_icloud() -> void:
	assert_true(_cloud.is_available())


func test_a_write_then_a_read_gives_the_same_text() -> void:
	var text := "eJzLSM3JyVcozy/KSQEAGgQEXQ== ünïcode"

	var written := _cloud.write(text)
	var read := _cloud.read()

	assert_true(written.is_ok())
	assert_eq(read.text, text)
	assert_eq(_store.values.keys(), [CloudSave.SAVE_NAME])
	assert_eq(_store.synchronized, 2, "each read and each write tells iCloud")


func test_a_store_with_no_save_reads_as_an_empty_text() -> void:
	var read := _cloud.read()

	assert_true(read.is_ok())
	assert_eq(read.text, "")


func test_a_store_that_cannot_sync_fails() -> void:
	# synchronize() is false, for example, when the build has no iCloud
	# entitlement.
	_store.synchronize_works = false

	assert_eq(_cloud.read().status, CloudOperation.Status.FAILED)
	assert_eq(_cloud.write("text").status, CloudOperation.Status.FAILED)


func test_a_save_that_is_too_large_is_not_written() -> void:
	var text := "x".repeat(ICloudSave.MAX_BYTES + 1)

	var written := _cloud.write(text)

	assert_eq(written.status, CloudOperation.Status.FAILED)
	assert_string_contains(written.message, "too large")
	assert_true(_store.values.is_empty())


func test_a_write_that_the_store_refuses_fails() -> void:
	_store.set_works = false

	assert_eq(_cloud.write("text").status, CloudOperation.Status.FAILED)
