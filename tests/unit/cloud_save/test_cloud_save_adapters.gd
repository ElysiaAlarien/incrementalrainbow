extends GutTest
## The cloud-save adapters: the test adapter, and the platform adapters with
## no SDK or plugin, which is the case in CI and on a computer with no Steam.

const FOLDER := "user://test_cloud_save_adapter"


func after_each() -> void:
	var path := FOLDER.path_join(TestCloudSave.FILE_NAME)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(FOLDER):
		DirAccess.remove_absolute(FOLDER)


func _platform_adapters() -> Array[CloudSave]:
	return [CloudSave.new(), SteamCloudSave.new(), ICloudSave.new(), GooglePlayCloudSave.new()]


func test_each_platform_adapter_with_no_sdk_is_not_available_and_answers_at_once() -> void:
	for cloud in _platform_adapters():
		var where := cloud.service_name()
		assert_false(cloud.is_available(), where)
		var read := cloud.read()
		var written := cloud.write("text")
		assert_eq(read.status, CloudOperation.Status.NOT_AVAILABLE, where)
		assert_eq(written.status, CloudOperation.Status.NOT_AVAILABLE, where)
		assert_false(read.message.is_empty(), where)
		assert_eq((await read.wait(1.0)).status, CloudOperation.Status.NOT_AVAILABLE, where)


func test_each_platform_adapter_has_a_name_for_the_player() -> void:
	var names: Array[String] = []
	for cloud in _platform_adapters():
		names.append(cloud.service_name())
	assert_eq(names, ["cloud save", "Steam Cloud", "iCloud", "Google Play"])


func test_the_device_picks_its_adapter() -> void:
	var none := PackedStringArray()
	assert_true(CloudSaves.for_device("Windows", none) is SteamCloudSave)
	assert_true(CloudSaves.for_device("macOS", none) is SteamCloudSave)
	assert_true(CloudSaves.for_device("Linux", none) is SteamCloudSave)
	assert_true(CloudSaves.for_device("iOS", none) is ICloudSave)
	assert_true(CloudSaves.for_device("Android", none) is GooglePlayCloudSave)
	var web := CloudSaves.for_device("Web", none)
	assert_eq(web.get_script(), CloudSave)


func test_a_command_line_folder_picks_the_test_adapter() -> void:
	var cloud := CloudSaves.for_device("Linux", PackedStringArray(["--other", "--test-cloud-save=%s" % FOLDER]))

	assert_true(cloud is TestCloudSave)
	assert_eq((cloud as TestCloudSave).folder, FOLDER)


func test_the_test_adapter_keeps_the_save_in_memory() -> void:
	var cloud := TestCloudSave.new()

	var empty := cloud.read()
	var written := cloud.write("a save")
	var read := cloud.read()

	assert_true(empty.is_ok())
	assert_eq(empty.text, "")
	assert_true(written.is_ok())
	assert_eq(read.text, "a save")
	assert_eq([cloud.reads, cloud.writes], [2, 1])


func test_two_test_adapters_with_one_folder_share_the_save() -> void:
	var device_a := TestCloudSave.new(FOLDER)
	var device_b := TestCloudSave.new(FOLDER)

	device_a.write("from device a")

	assert_eq(device_b.read().text, "from device a")


func test_the_test_adapter_fails_on_request() -> void:
	var cloud := TestCloudSave.new()
	cloud.fail_next_read = "No network."
	cloud.fail_next_write = "Full."

	var read := cloud.read()
	var written := cloud.write("text")

	assert_eq(read.status, CloudOperation.Status.FAILED)
	assert_eq(read.message, "No network.")
	assert_eq(written.status, CloudOperation.Status.FAILED)
	assert_eq(cloud.stored_text(), "")
	assert_true(cloud.read().is_ok(), "only the next one fails")


func test_the_test_adapter_can_be_signed_out() -> void:
	var cloud := TestCloudSave.new()
	cloud.available = false

	assert_false(cloud.is_available())
	assert_eq(cloud.read().status, CloudOperation.Status.NOT_AVAILABLE)
	assert_eq(cloud.write("text").status, CloudOperation.Status.NOT_AVAILABLE)


func test_the_test_adapter_can_hold_its_answers() -> void:
	var cloud := TestCloudSave.new()
	cloud.hold_answers = true

	var written := cloud.write("later")
	assert_false(written.is_done())
	assert_eq(cloud.held_count(), 1)
	cloud.answer_held()

	assert_true(written.is_ok())
	assert_eq(cloud.stored_text(), "later")


func test_an_operation_counts_only_its_first_answer() -> void:
	var operation := CloudOperation.new()
	watch_signals(operation)

	operation.succeed("first")
	operation.fail(CloudOperation.Status.FAILED, "late")
	operation.succeed("second")

	assert_eq(operation.status, CloudOperation.Status.OK)
	assert_eq(operation.text, "first")
	assert_signal_emit_count(operation, "finished", 1)


func test_waiting_for_an_operation_with_a_timeout_fails_it() -> void:
	var operation := CloudOperation.new()

	await operation.wait(0.05)

	assert_eq(operation.status, CloudOperation.Status.FAILED)
	assert_string_contains(operation.message, "did not answer")


func test_waiting_for_an_operation_gets_its_later_answer() -> void:
	var operation := CloudOperation.new()
	get_tree().create_timer(0.02).timeout.connect(func() -> void: operation.succeed("answer"))

	await operation.wait(5.0)

	assert_eq(operation.text, "answer")
