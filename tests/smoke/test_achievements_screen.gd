extends GutTest
## Smoke tests: the main screen unlocks platform achievements through the test
## adapter (#25). A sale that the player makes unlocks the first sale, and a
## save from earlier play unlocks its achievements when the game starts.

const MainScene := preload("res://src/ui/main.tscn")
## A save path of its own, so that tests never touch the player's save.
const SAVE_PATH := "user://test_saves/achievements_screen.json"
## The device clock of the tests: a time in November 2026.
const NOW_UNIX_MS := 1_795_000_000_000


func before_each() -> void:
	for path in [SAVE_PATH, SAVE_PATH + SaveFile.DAMAGED_SUFFIX, SAVE_PATH + SaveFile.TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func after_all() -> void:
	before_each()


func _open_main(service: AchievementService) -> Control:
	var main: Control = MainScene.instantiate()
	main.save_path = SAVE_PATH
	main.clock = func() -> int: return NOW_UNIX_MS
	main.achievement_service = service
	add_child_autofree(main)
	await wait_process_frames(1)
	return main


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


func test_an_import_unlocks_the_achievements_of_the_code() -> void:
	var service := TestAchievementService.new()
	var main := await _open_main(service)
	var other := Simulation.new(Content.load_dir(Content.DEFAULT_DIR), 2)
	other.build_factory(&"red")
	other.buy_prism()
	var imported := SaveCodec.decode(Content.load_dir(Content.DEFAULT_DIR), SaveCodec.encode(other, NOW_UNIX_MS))
	assert_true(imported.ok, imported.message)

	var dialog: ExportCodeDialog = main.find_children("*", "ExportCodeDialog", true, false)[0]
	dialog.import_confirmed.emit(imported)
	# The rows of the last run go at the end of the frame.
	await wait_process_frames(1)

	assert_true(service.unlocked.has(&"first_prism"))
