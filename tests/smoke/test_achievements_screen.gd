extends GutTest
## Smoke tests: the main screen unlocks platform achievements through the test
## adapter (#25). A sale that the player makes unlocks the first sale, and a
## save from earlier play unlocks its achievements when the game starts. An
## imported code of another player unlocks nothing, and a cloud save of the
## player's own game does (ADR-0019).

const MainScene := preload("res://src/ui/main.tscn")
## A save path of its own, so that tests never touch the player's save.
const SAVE_PATH := "user://test_saves/achievements_screen.json"
## The device clock of the tests: a time in November 2026.
const NOW_UNIX_MS := 1_795_000_000_000

## The cloud save of the screen, so that tests never touch a platform cloud.
var _cloud: TestCloudSave


func before_each() -> void:
	_cloud = TestCloudSave.new()
	for suffix in ["", SaveFile.DAMAGED_SUFFIX, SaveFile.TEMP_SUFFIX, CloudSyncRecord.SUFFIX,
			CloudSaveSession.KEPT_SUFFIX]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(SAVE_PATH + suffix)


func after_all() -> void:
	before_each()


func _open_main(service: AchievementService) -> Control:
	var main: Control = MainScene.instantiate()
	main.save_path = SAVE_PATH
	main.clock = func() -> int: return NOW_UNIX_MS
	main.achievement_service = service
	main.cloud_save = _cloud
	add_child_autofree(main)
	await wait_process_frames(2)
	return main


## The export code of a game with a red factory and a prism. With
## [param imported] true, that game came from an import of another player's
## code on another device.
func _code_with_a_prism(imported: bool) -> String:
	var sim := Simulation.new(Content.load_dir(Content.DEFAULT_DIR), 2)
	sim.build_factory(&"red")
	sim.buy_prism()
	if imported:
		sim.mark_milestones_imported()
	return ExportCode.encode(sim, NOW_UNIX_MS - 60_000)


func test_the_first_sale_on_the_screen_unlocks_its_achievement() -> void:
	var service := TestAchievementService.new()
	var main := await _open_main(service)
	var sim: Simulation = main.simulation()
	main.find_child("Build_red", true, false).pressed.emit()
	main.find_child("MakeLink", true, false).pressed.emit()
	await wait_process_frames(1)
	sim.tick(3000)
	var row: LinkRow = main.find_children("Link*", "LinkRow", true, false)[0]
	row.ship_button().pressed.emit()
	assert_false(service.unlocked.has(&"first_sale"), "a shipment on its way is not a sale")

	sim.tick(sim.link(row.link_id).transit_time_ms)

	assert_true(service.unlocked.has(&"first_sale"))


func test_a_save_from_earlier_play_unlocks_its_achievements_on_start() -> void:
	var sim := Simulation.new(Content.load_dir(Content.DEFAULT_DIR), 1)
	sim.build_factory(&"red")
	sim.buy_prism()
	assert_eq(SaveFile.new(SAVE_PATH).write(SaveCodec.encode(sim, NOW_UNIX_MS)), OK)
	var service := TestAchievementService.new()

	await _open_main(service)

	assert_true(service.unlocked.has(&"first_prism"))
	assert_false(service.unlocked.has(&"first_sale"))


func test_an_import_of_a_code_unlocks_nothing_also_at_the_next_start() -> void:
	var service := TestAchievementService.new()
	var main := await _open_main(service)
	var imported := ExportCode.decode(Content.load_dir(Content.DEFAULT_DIR), _code_with_a_prism(false))
	assert_true(imported.ok, imported.message)

	var dialog: ExportCodeDialog = main.find_children("*", "ExportCodeDialog", true, false)[0]
	dialog.import_confirmed.emit(imported)
	# The rows of the last run go at the end of the frame.
	await wait_process_frames(1)
	assert_eq(main.simulation().milestones().get(Milestones.PRISMS_BOUGHT, 0), 1)
	assert_false(service.unlocked.has(&"first_prism"))
	main.queue_free()
	await wait_process_frames(1)

	var next_start := TestAchievementService.new()
	main = await _open_main(next_start)

	assert_eq(main.simulation().milestones().get(Milestones.PRISMS_BOUGHT, 0), 1, "the save has the import")
	assert_false(next_start.unlocked.has(&"first_prism"))


func test_a_cloud_save_of_the_players_own_game_unlocks_its_achievements() -> void:
	_cloud.put(_code_with_a_prism(false))
	var service := TestAchievementService.new()

	var main := await _open_main(service)

	assert_eq(main.simulation().milestones().get(Milestones.PRISMS_BOUGHT, 0), 1, "the cloud save loaded")
	assert_true(service.unlocked.has(&"first_prism"))


func test_a_cloud_save_of_an_imported_game_unlocks_nothing() -> void:
	_cloud.put(_code_with_a_prism(true))
	var service := TestAchievementService.new()

	var main := await _open_main(service)

	assert_eq(main.simulation().milestones().get(Milestones.PRISMS_BOUGHT, 0), 1, "the cloud save loaded")
	assert_false(service.unlocked.has(&"first_prism"))
