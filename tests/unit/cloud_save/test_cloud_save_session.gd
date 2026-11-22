extends GutTest
## A sync with a cloud save: what it reads and writes, what it records, and
## what it keeps, with the test adapter as the cloud.

const SAVE_PATH := "user://test_cloud_session_save.json"
const EARLY_MS := 1_795_000_000_000
const LATE_MS := EARLY_MS + 3_600_000

var _content: Content
var _cloud: TestCloudSave


func before_each() -> void:
	_content = ContentFixture.make_for_saves()
	_cloud = TestCloudSave.new()
	_remove_files()


func after_each() -> void:
	_remove_files()


func _remove_files() -> void:
	for path in [SAVE_PATH + CloudSyncRecord.SUFFIX, SAVE_PATH + CloudSaveSession.KEPT_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _session() -> CloudSaveSession:
	return CloudSaveSession.new(_cloud, _content, SAVE_PATH)


func _code(factories: int, saved_at_unix_ms: int) -> String:
	var sim := Simulation.new(_content, 5)
	for i in factories:
		sim.build_factory(&"red")
	return ExportCode.encode(sim, saved_at_unix_ms)


func test_a_first_sync_uploads_and_a_second_sync_with_no_change_does_nothing() -> void:
	var local := _code(1, EARLY_MS)

	var first := await _session().sync(local, EARLY_MS, true)
	var second := await _session().sync(local, EARLY_MS, true)

	assert_eq(first.action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(_cloud.stored_text(), local)
	assert_eq(second.action, CloudSyncPlan.Action.NOTHING)
	assert_eq(_cloud.writes, 1)


func test_play_on_the_device_uploads_with_no_conflict() -> void:
	await _session().sync(_code(1, EARLY_MS), EARLY_MS, true)
	var later := _code(2, LATE_MS)

	var plan := await _session().sync(later, LATE_MS, true)

	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.NONE)
	assert_eq(_cloud.stored_text(), later)


func test_play_on_another_device_comes_to_this_one() -> void:
	var local := _code(1, EARLY_MS)
	await _session().sync(local, EARLY_MS, true)
	var other_device := _code(3, LATE_MS)
	_cloud.put(other_device)

	var plan := await _session().sync(local, EARLY_MS, true)
	var after := await _session().sync(other_device, LATE_MS, true)

	assert_eq(plan.action, CloudSyncPlan.Action.USE_CLOUD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.LOADED_FROM_CLOUD)
	assert_eq(after.action, CloudSyncPlan.Action.NOTHING, "the sync of the cloud save was recorded")


func test_a_new_game_marked_on_the_device_takes_the_cloud_save() -> void:
	_cloud.put(_code(4, EARLY_MS))
	var session := _session()
	session.mark_new_game()

	var plan := await _session().sync(_code(0, LATE_MS), LATE_MS, true)

	assert_eq(plan.action, CloudSyncPlan.Action.USE_CLOUD)
	assert_eq(plan.cloud.simulation.factories().size(), 4)


func test_a_conflict_keeps_the_save_that_lost_on_the_device() -> void:
	var cloud := _code(2, EARLY_MS)
	_cloud.put(cloud)
	var session := _session()

	var plan := await session.sync(_code(1, LATE_MS), LATE_MS, true)

	assert_eq(plan.notice, CloudSyncPlan.Notice.CONFLICT)
	assert_eq(session.kept_code(), cloud)
	assert_eq(_cloud.stored_text(), _code(1, LATE_MS))


func test_a_sync_that_cannot_tell_the_player_only_uploads() -> void:
	var cloud := _code(2, LATE_MS)
	_cloud.put(cloud)
	var session := _session()

	var plan := await session.sync(_code(1, EARLY_MS), EARLY_MS, false)

	assert_eq(plan.action, CloudSyncPlan.Action.NOTHING)
	assert_eq(plan.notice, CloudSyncPlan.Notice.NONE)
	assert_eq(_cloud.stored_text(), cloud, "the conflict waits for the next sync")
	assert_eq(session.kept_code(), "")


func test_a_failed_write_records_no_sync_and_tells_the_player() -> void:
	_cloud.fail_next_write = "The cloud is full."
	var local := _code(1, EARLY_MS)

	var plan := await _session().sync(local, EARLY_MS, true)
	var again := await _session().sync(local, EARLY_MS, true)

	assert_eq(plan.notice, CloudSyncPlan.Notice.UNREACHABLE)
	assert_eq(plan.message, "The cloud is full.")
	assert_eq(again.action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(again.notice, CloudSyncPlan.Notice.NONE)
	assert_eq(_cloud.stored_text(), local)


func test_a_cloud_save_of_a_newer_game_stops_each_later_sync() -> void:
	var save := JSON.parse_string(SaveCodec.encode(Simulation.new(_content, 5), LATE_MS)) as Dictionary
	save.applied.append("a_change_of_a_newer_game")
	var newer := ExportCode.from_save(JSON.stringify(save), SaveCodec.VERSION)
	_cloud.put(newer)
	var session := _session()

	var plan := await session.sync(_code(1, EARLY_MS), EARLY_MS, true)
	var later := await session.sync(_code(1, EARLY_MS), EARLY_MS, true)

	assert_eq(plan.notice, CloudSyncPlan.Notice.CLOUD_NEWER)
	assert_true(session.is_stopped())
	assert_null(later)
	assert_eq(_cloud.stored_text(), newer)
	assert_eq(_cloud.writes, 0)


func test_a_service_that_answers_later_finishes_the_sync_later() -> void:
	_cloud.hold_answers = true
	var session := _session()
	var plans: Array[CloudSyncPlan] = []
	session.synced.connect(func(plan: CloudSyncPlan) -> void: plans.append(plan))

	session.sync(_code(1, EARLY_MS), EARLY_MS, true)
	assert_true(session.is_busy())
	assert_null(await session.sync(_code(1, EARLY_MS), EARLY_MS, true), "one sync at a time")
	_cloud.answer_held()
	await wait_process_frames(1)
	_cloud.answer_held()
	await wait_process_frames(1)

	assert_eq(plans.size(), 1)
	assert_eq(plans[0].action, CloudSyncPlan.Action.UPLOAD)
	assert_false(session.is_busy())
	assert_eq(_cloud.stored_text(), _code(1, EARLY_MS))


func test_a_service_that_never_answers_times_out() -> void:
	_cloud.hold_answers = true
	var session := _session()
	session.timeout_s = 0.05

	var plan := await session.sync(_code(1, EARLY_MS), EARLY_MS, true)

	assert_eq(plan.notice, CloudSyncPlan.Notice.UNREACHABLE)
	assert_false(session.is_busy())
	_cloud.answer_held()
	assert_eq(_cloud.writes, 0, "a late answer does nothing")


func test_a_damaged_record_acts_as_no_sync() -> void:
	var file := FileAccess.open(SAVE_PATH + CloudSyncRecord.SUFFIX, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	_cloud.put(_code(2, EARLY_MS))

	var plan := await _session().sync(_code(1, LATE_MS), LATE_MS, true)

	assert_eq(plan.notice, CloudSyncPlan.Notice.CONFLICT)
