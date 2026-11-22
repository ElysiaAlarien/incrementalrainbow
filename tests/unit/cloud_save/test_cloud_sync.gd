extends GutTest
## The rule for a sync between the save on the device and the cloud save
## (ADR-0018), case by case.

## Save times in November 2026.
const EARLY_MS := 1_795_000_000_000
const LATE_MS := EARLY_MS + 3_600_000

var _content: Content


func before_each() -> void:
	_content = ContentFixture.make_for_saves()


## The export code of a small game, saved at [param saved_at_unix_ms]. Each
## [param factories] makes a different game.
func _code(factories: int, saved_at_unix_ms: int) -> String:
	var sim := Simulation.new(_content, 5)
	for i in factories:
		sim.build_factory(&"red")
	sim.tick(1000)
	return ExportCode.encode(sim, saved_at_unix_ms)


func _decide(local_code: String, local_saved_at: int, cloud_text: String, base: String,
		local_is_new := false) -> CloudSyncPlan:
	return CloudSync.decide(_content, local_code, local_saved_at, local_is_new,
		CloudOperation.done(cloud_text), base)


func test_no_service_does_nothing() -> void:
	var plan := CloudSync.decide(_content, _code(1, EARLY_MS), EARLY_MS, false,
		CloudOperation.not_available("none"), "")

	assert_eq(plan.action, CloudSyncPlan.Action.NOTHING)
	assert_eq(plan.notice, CloudSyncPlan.Notice.NONE)
	assert_false(plan.needs_the_player())


func test_a_failed_read_changes_nothing_and_tells_the_player() -> void:
	var plan := CloudSync.decide(_content, _code(1, EARLY_MS), EARLY_MS, false,
		CloudOperation.failed("No network."), "")

	assert_eq(plan.action, CloudSyncPlan.Action.NOTHING)
	assert_eq(plan.notice, CloudSyncPlan.Notice.UNREACHABLE)
	assert_eq(plan.message, "No network.")


func test_an_empty_cloud_gets_the_game_on_the_device() -> void:
	var local := _code(1, EARLY_MS)

	var plan := _decide(local, EARLY_MS, "", "")

	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.NONE)
	assert_eq(plan.synced_sha256, local.sha256_text())


func test_the_same_save_on_both_sides_only_records_the_sync() -> void:
	var local := _code(1, EARLY_MS)

	var plan := _decide(local, EARLY_MS, local, "")

	assert_eq(plan.action, CloudSyncPlan.Action.NOTHING)
	assert_eq(plan.notice, CloudSyncPlan.Notice.NONE)
	assert_eq(plan.synced_sha256, local.sha256_text())


func test_only_the_device_changed_so_it_uploads() -> void:
	var cloud := _code(1, EARLY_MS)

	var plan := _decide(_code(2, LATE_MS), LATE_MS, cloud, cloud.sha256_text())

	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.NONE)
	assert_eq(plan.kept_code, "", "nothing is lost, so no copy")


func test_only_the_device_changed_uploads_even_when_the_cloud_save_is_later() -> void:
	# The rule of the save times is only for a conflict.
	var cloud := _code(1, LATE_MS)

	var plan := _decide(_code(2, EARLY_MS), EARLY_MS, cloud, cloud.sha256_text())

	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)


func test_only_the_cloud_changed_so_the_game_uses_it_and_tells_the_player() -> void:
	var local := _code(1, LATE_MS)
	var cloud := _code(3, EARLY_MS)

	var plan := _decide(local, LATE_MS, cloud, local.sha256_text())

	assert_eq(plan.action, CloudSyncPlan.Action.USE_CLOUD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.LOADED_FROM_CLOUD)
	assert_true(plan.cloud.ok)
	assert_eq(plan.cloud.simulation.factories().size(), 3)
	assert_eq(plan.used_saved_at_unix_ms, EARLY_MS)
	assert_eq(plan.synced_sha256, cloud.sha256_text())
	assert_eq(plan.kept_code, local, "the game on the device is kept")


func test_a_new_game_on_the_device_never_replaces_a_cloud_save() -> void:
	# A new install: its new game saved last, but it must not win.
	var local := _code(0, LATE_MS)
	var cloud := _code(4, EARLY_MS)

	var plan := _decide(local, LATE_MS, cloud, "", true)

	assert_eq(plan.action, CloudSyncPlan.Action.USE_CLOUD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.REPLACED_NEW_GAME)
	assert_true(plan.needs_the_player())
	assert_eq(plan.cloud.simulation.factories().size(), 4)
	assert_eq(plan.kept_code, local)
	assert_eq(plan.kept_saved_at_unix_ms, LATE_MS)


func test_a_new_game_on_a_device_that_synced_before_never_replaces_the_cloud_save() -> void:
	# The save on the device did not load, so a new game started, but the
	# cloud save did not change since the last sync of this device.
	var cloud := _code(4, EARLY_MS)

	var plan := _decide(_code(0, LATE_MS), LATE_MS, cloud, cloud.sha256_text(), true)

	assert_eq(plan.action, CloudSyncPlan.Action.USE_CLOUD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.REPLACED_NEW_GAME)
	assert_eq(plan.cloud.simulation.factories().size(), 4)


func test_a_conflict_uses_the_cloud_save_when_it_saved_last() -> void:
	var local := _code(1, EARLY_MS)
	var cloud := _code(2, LATE_MS)

	var plan := _decide(local, EARLY_MS, cloud, "an older sync")

	assert_eq(plan.action, CloudSyncPlan.Action.USE_CLOUD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.CONFLICT)
	assert_true(plan.picked_cloud)
	assert_eq(plan.used_saved_at_unix_ms, LATE_MS)
	assert_eq(plan.kept_code, local)
	assert_eq(plan.kept_saved_at_unix_ms, EARLY_MS)


func test_a_conflict_uploads_the_device_when_it_saved_last() -> void:
	var local := _code(1, LATE_MS)
	var cloud := _code(2, EARLY_MS)

	var plan := _decide(local, LATE_MS, cloud, "an older sync")

	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.CONFLICT)
	assert_false(plan.picked_cloud)
	assert_eq(plan.used_saved_at_unix_ms, LATE_MS)
	assert_eq(plan.kept_code, cloud, "the cloud save is kept before the upload")
	assert_eq(plan.kept_saved_at_unix_ms, EARLY_MS)
	assert_eq(plan.synced_sha256, local.sha256_text())


func test_a_device_that_never_synced_has_a_conflict() -> void:
	var plan := _decide(_code(1, LATE_MS), LATE_MS, _code(2, EARLY_MS), "")

	assert_eq(plan.notice, CloudSyncPlan.Notice.CONFLICT)
	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)


func test_a_conflict_with_the_same_save_time_keeps_the_device() -> void:
	var plan := _decide(_code(1, EARLY_MS), EARLY_MS, _code(2, EARLY_MS), "")

	assert_eq(plan.notice, CloudSyncPlan.Notice.CONFLICT)
	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)


func test_a_device_save_with_no_save_time_loses_a_conflict() -> void:
	var plan := _decide(_code(1, EARLY_MS), LoadResult.NO_SAVE_TIME, _code(2, EARLY_MS), "")

	assert_eq(plan.notice, CloudSyncPlan.Notice.CONFLICT)
	assert_eq(plan.action, CloudSyncPlan.Action.USE_CLOUD)
	assert_eq(plan.kept_saved_at_unix_ms, LoadResult.NO_SAVE_TIME)


func test_a_damaged_cloud_save_is_kept_and_replaced() -> void:
	var local := _code(1, EARLY_MS)
	var damaged := _code(2, EARLY_MS).substr(0, 40)

	var plan := _decide(local, EARLY_MS, damaged, "")

	assert_eq(plan.action, CloudSyncPlan.Action.UPLOAD)
	assert_eq(plan.notice, CloudSyncPlan.Notice.CLOUD_DAMAGED)
	assert_eq(plan.kept_code, damaged)
	assert_false(plan.message.is_empty())


func test_a_cloud_save_of_a_newer_game_stops_the_sync_and_is_not_overwritten() -> void:
	var save := JSON.parse_string(SaveCodec.encode(Simulation.new(_content, 5), LATE_MS)) as Dictionary
	save.applied.append("a_change_of_a_newer_game")
	var newer := ExportCode.from_save(JSON.stringify(save), SaveCodec.VERSION)

	var plan := _decide(_code(1, EARLY_MS), EARLY_MS, newer, "", true)

	assert_eq(plan.action, CloudSyncPlan.Action.STOP)
	assert_eq(plan.notice, CloudSyncPlan.Notice.CLOUD_NEWER)
	assert_eq(plan.kept_code, "")
