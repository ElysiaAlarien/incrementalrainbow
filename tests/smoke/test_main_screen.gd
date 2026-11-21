extends GutTest
## Smoke tests: the main screen loads, builds a factory, shows it, and keeps it
## in a save.

const MainScene := preload("res://src/ui/main.tscn")
## A save path of its own, so that tests never touch the player's save.
const SAVE_PATH := "user://test_saves/main_screen.json"


func before_each() -> void:
	for path in [SAVE_PATH, SAVE_PATH + SaveFile.DAMAGED_SUFFIX, SAVE_PATH + SaveFile.TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func after_all() -> void:
	before_each()


func _open_main() -> Control:
	var main: Control = MainScene.instantiate()
	main.save_path = SAVE_PATH
	add_child_autofree(main)
	await wait_process_frames(1)
	return main


## The save that the screen wrote.
func _read_save() -> LoadResult:
	return SaveCodec.decode(Content.load_dir(Content.DEFAULT_DIR), FileAccess.get_file_as_string(SAVE_PATH))


func _rows(main: Control) -> Array[Node]:
	return main.find_children("Factory*", "FactoryRow", true, false)


func test_building_a_factory_shows_it_on_the_screen() -> void:
	var main := await _open_main()

	var button: Button = main.find_child("Build_red", true, false)
	assert_not_null(button, "a build button for red")
	assert_not_null(button.icon, "the button shows the red symbol")
	button.pressed.emit()
	main.simulation().tick(60_000)
	await wait_process_frames(1)

	var rows := _rows(main)
	assert_eq(rows.size(), 1)
	var row: FactoryRow = rows[0]
	assert_eq(row.bay_text(), "Output bay: 10 / 10")
	assert_eq(row.status_text(), "Stopped: output bay full")
	assert_false(main.find_child("EmptyLabel", true, false).visible)


## The main screen with one red factory built.
func _main_with_red_factory() -> Control:
	var main := await _open_main()
	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	return main


func _first_row(main: Control) -> FactoryRow:
	return main.find_children("Factory*", "FactoryRow", true, false)[0]


func test_adding_a_production_line_shows_the_new_size_and_money() -> void:
	var main: Control = await _main_with_red_factory()
	var row := _first_row(main)
	assert_eq(row.size_text(), "1 line")
	var money_before: BigNumber = main.simulation().money()
	row.add_line_button().pressed.emit()
	await wait_process_frames(1)

	assert_eq(row.size_text(), "2 lines")
	assert_true(main.simulation().money().is_less_than(money_before), "the line cost money")
	var money_label: Label = main.find_child("MoneyLabel", true, false)
	assert_eq(money_label.text, "Money: %s" % main.simulation().money().format())


func test_adding_a_line_with_too_little_money_shows_the_reason() -> void:
	var main: Control = await _main_with_red_factory()
	var row := _first_row(main)

	# Add lines until the money runs out; the last press fails.
	var message_label: Label = main.find_child("MessageLabel", true, false)
	for i in 1000:
		row.add_line_button().pressed.emit()
		if message_label.visible:
			break

	assert_true(message_label.visible, "a reason is shown")
	assert_string_contains(message_label.text, "costs")


func test_the_game_saves_on_exit_and_loads_on_start() -> void:
	var first := await _open_main()
	first.find_child("Build_red", true, false).pressed.emit()
	first.simulation().tick(3_500)
	var saved_snapshot: Dictionary = first.simulation().snapshot()
	remove_child(first)
	first.free()
	var saved := _read_save()
	assert_true(saved.ok, "the exit saved the game: %s" % saved.message)
	assert_eq(saved.simulation.snapshot(), saved_snapshot)

	var second := await _open_main()

	assert_eq(second.simulation().factories()[0].id, 1)
	assert_gte(second.simulation().time_ms(), 3_500)
	var rows := _rows(second)
	assert_eq(rows.size(), 1)
	assert_eq((rows[0] as FactoryRow).bay_text(), "Output bay: 3 / 10")


func test_the_game_saves_at_intervals() -> void:
	var main := await _open_main()
	var autosave: Timer = main.find_child("Autosave", true, false)
	assert_not_null(autosave)
	assert_false(autosave.is_stopped())
	assert_false(autosave.one_shot)
	assert_eq(autosave.wait_time, main.AUTOSAVE_INTERVAL_S)

	main.find_child("Build_blue", true, false).pressed.emit()
	autosave.timeout.emit()

	var result := _read_save()
	assert_true(result.ok, result.message)
	assert_eq(result.simulation.factories().size(), 1)


func test_a_damaged_save_starts_a_new_game_and_keeps_a_copy() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"format\": \"incremental-rainbow-save\", \"vers")
	file.close()

	var main := await _open_main()

	assert_eq(_rows(main).size(), 0, "a new game")
	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "could not load")
	assert_string_contains(message.text, "not valid JSON")
	assert_eq(FileAccess.get_file_as_string(SAVE_PATH + SaveFile.DAMAGED_SUFFIX),
		"{\"format\": \"incremental-rainbow-save\", \"vers", "the damaged save is kept")


func test_a_damaged_save_that_cannot_move_is_not_overwritten() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	# A folder with a file in it at the copy's path makes the move fail.
	var blocker := SAVE_PATH + SaveFile.DAMAGED_SUFFIX
	DirAccess.make_dir_recursive_absolute(blocker)
	FileAccess.open(blocker.path_join("keep"), FileAccess.WRITE).close()

	var main := await _open_main()
	main.write_save()
	remove_child(main)
	main.free()

	assert_eq(FileAccess.get_file_as_string(SAVE_PATH), "not a save", "the damaged save is not overwritten")
	DirAccess.remove_absolute(blocker.path_join("keep"))
	DirAccess.remove_absolute(blocker)
