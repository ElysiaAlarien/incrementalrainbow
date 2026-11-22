extends GutTest
## Smoke tests: the main screen shows the guided start on a new game, moves it
## on as the player does each step, and hides it after a skip, also after a
## restart and a prestige.

const MainScene := preload("res://src/ui/main.tscn")
## A save path of its own, so that tests never touch the player's save.
const SAVE_PATH := "user://test_saves/guided_start.json"
const NOW_UNIX_MS := 1_795_000_000_000


func before_each() -> void:
	for path in [SAVE_PATH, SAVE_PATH + SaveFile.DAMAGED_SUFFIX, SAVE_PATH + SaveFile.TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func after_all() -> void:
	before_each()


func _open_main() -> Control:
	var main: Control = MainScene.instantiate()
	main.save_path = SAVE_PATH
	main.clock = func() -> int: return NOW_UNIX_MS
	add_child_autofree(main)
	await wait_process_frames(1)
	return main


func _close(main: Control) -> void:
	remove_child(main)
	main.free()


func _banner(main: Control) -> GuidedStartBanner:
	return main.find_child("GuidedStart", true, false)


func _press(main: Control, node_name: String) -> void:
	(main.find_child(node_name, true, false) as Button).pressed.emit()
	await wait_process_frames(1)


func test_a_new_game_shows_the_first_step() -> void:
	var main := await _open_main()

	var banner := _banner(main)
	assert_true(banner.visible)
	assert_eq(banner.text(), "Guide 1 / 4: %s" % GuidedStartBanner.step_text(GuidedStartView.Step.BUILD_FACTORY))


func test_each_action_moves_the_guide_on_until_it_hides() -> void:
	var main := await _open_main()
	var banner := _banner(main)

	await _press(main, "Build_red")
	assert_string_contains(banner.text(), "Guide 2 / 4")
	await _press(main, "MakeLink")
	assert_string_contains(banner.text(), "Guide 3 / 4")
	main.simulation().tick(3000)
	var row: LinkRow = main.find_children("Link*", "LinkRow", true, false)[0]
	row.ship_button().pressed.emit()
	await wait_process_frames(1)
	assert_eq(banner.text(), "Guide 4 / 4: %s" % GuidedStartBanner.step_text(GuidedStartView.Step.SELL))
	main.simulation().tick(main.simulation().link(row.link_id).transit_time_ms)
	await wait_process_frames(1)

	assert_false(banner.visible, "the sale ends the guide")


func test_skip_hides_the_guide_and_a_restart_keeps_it_hidden() -> void:
	var main := await _open_main()

	await _press(main, "SkipGuidedStart")

	assert_false(_banner(main).visible)
	assert_eq(main.simulation().guided_start().step, GuidedStartView.Step.SKIPPED)
	_close(main)
	var again := await _open_main()
	assert_false(_banner(again).visible, "the save keeps the skip")


func test_a_prestige_does_not_show_the_guide_again() -> void:
	var main := await _open_main()
	await _press(main, "SkipGuidedStart")
	await _press(main, "BuyPrism")
	await _press(main, "PrestigeButton")

	(main.find_child("PrestigeConfirm", true, false) as ConfirmationDialog).confirmed.emit()
	await wait_process_frames(1)

	assert_eq(main.simulation().factories().size(), 0, "a new run")
	assert_false(_banner(main).visible)
