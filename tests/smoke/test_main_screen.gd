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
	first.find_child("MakeLink", true, false).pressed.emit()
	first.simulation().add_production_line(1)
	first.simulation().tick(1_750)
	var saved_snapshot: Dictionary = first.simulation().snapshot()
	remove_child(first)
	first.free()
	var saved := _read_save()
	assert_true(saved.ok, "the exit saved the game: %s" % saved.message)
	assert_eq(saved.simulation.snapshot(), saved_snapshot)

	var second := await _open_main()

	assert_eq(second.simulation().factories()[0].id, 1)
	assert_gte(second.simulation().time_ms(), 1_750)
	var rows := _rows(second)
	assert_eq(rows.size(), 1)
	assert_eq((rows[0] as FactoryRow).bay_text(), "Output bay: 3 / 10")
	assert_eq((rows[0] as FactoryRow).size_text(), "2 lines")
	assert_true(second.simulation().money().equals(saved.simulation.money()))
	assert_eq(second.find_children("Link*", "LinkRow", true, false).size(), 1, "the link is kept")


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
func test_a_factory_can_be_linked_to_a_market_and_ship_for_money() -> void:
	var main := await _open_main()
	var sim: Simulation = main.simulation()
	var money_label: Label = main.find_child("MoneyLabel", true, false)
	assert_eq(money_label.text, "Money: %s" % sim.money().format())
	assert_string_contains(main.find_child("Build_red", true, false).text,
		"(%s)" % sim.factory_build_cost().format())

	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	var factory_choice: OptionButton = main.find_child("NewLinkFactory", true, false)
	var market_choice: OptionButton = main.find_child("NewLinkMarket", true, false)
	assert_eq(factory_choice.get_item_text(factory_choice.selected), "Red factory #1")
	assert_eq(market_choice.get_item_text(market_choice.selected), "Millbrook")
	main.find_child("MakeLink", true, false).pressed.emit()
	await wait_process_frames(1)

	var rows := main.find_children("Link*", "LinkRow", true, false)
	assert_eq(rows.size(), 1)
	var row: LinkRow = rows[0]
	var link := sim.link(row.link_id)
	assert_string_contains(row.text(), "Vehicle: Cart")
	assert_string_contains(row.text(), "Cost: %s" % link.shipment_cost.format())
	assert_string_contains(row.text(), "Transit: %s" % LinkRow.format_seconds(link.transit_time_ms))
	assert_false(main.find_child("LinksEmptyLabel", true, false).visible)

	sim.tick(3000)
	var before_ship := sim.money()
	row.ship_button().pressed.emit()
	await wait_process_frames(1)
	assert_true(sim.money().is_less_than(before_ship), "the shipment cost money")
	assert_string_contains(row.text(), "widgets on the way")

	sim.tick(sim.link(row.link_id).transit_time_ms)
	await wait_process_frames(1)
	assert_true(sim.money().is_greater_than(before_ship), "the sale made money")
	assert_eq(money_label.text, "Money: %s" % sim.money().format())


func test_a_failed_command_shows_its_reason() -> void:
	var main := await _open_main()
	main.find_child("Build_red", true, false).pressed.emit()
	await wait_process_frames(1)
	var make_link: Button = main.find_child("MakeLink", true, false)
	make_link.pressed.emit()

	# The factory already has a link to this market.
	make_link.pressed.emit()
	await wait_process_frames(1)

	var message: Label = main.find_child("MessageLabel", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "already has a link")


# --- Export and import ----------------------------------------------------------

## Opens the export and import dialog of [param main].
func _open_export_code_dialog(main: Control) -> ExportCodeDialog:
	main.find_child("ExportCodeButton", true, false).pressed.emit()
	await wait_process_frames(1)
	var dialog: ExportCodeDialog = main.find_child("ExportCodeDialog", true, false)
	assert_true(dialog.visible, "the dialog opens")
	return dialog


func _import_code(dialog: ExportCodeDialog, code: String) -> ConfirmationDialog:
	(dialog.find_child("ImportCodeText", true, false) as TextEdit).text = code
	dialog.find_child("ImportCode", true, false).pressed.emit()
	await wait_process_frames(1)
	return dialog.find_child("ImportConfirm", true, false)


func test_the_export_code_imports_after_the_player_confirms() -> void:
	var main: Control = await _main_with_red_factory()
	main.find_child("MakeLink", true, false).pressed.emit()
	var dialog := await _open_export_code_dialog(main)
	var code := (dialog.find_child("ExportCodeText", true, false) as TextEdit).text
	var exported: Dictionary = ExportCode.decode(Content.load_dir(Content.DEFAULT_DIR), code).simulation.snapshot()
	# The game goes on: a second factory that the code does not have.
	main.find_child("Build_blue", true, false).pressed.emit()
	await wait_process_frames(1)
	assert_eq(_rows(main).size(), 2)

	var confirm := await _import_code(dialog, code)
	assert_true(confirm.visible, "the import asks to confirm")
	assert_eq(main.simulation().factories().size(), 2, "the game does not change before the player confirms")
	confirm.confirmed.emit()
	await wait_process_frames(1)

	assert_false(dialog.visible, "the dialog closes")
	assert_eq(main.simulation().factories().size(), 1)
	assert_gte(main.simulation().time_ms(), exported.time_ms)
	assert_eq(_rows(main).size(), 1, "the screen shows the imported game")
	assert_eq(main.find_children("Link*", "LinkRow", true, false).size(), 1)
	assert_eq((main.find_child("NewLinkFactory", true, false) as OptionButton).item_count, 1)
	var saved := _read_save()
	assert_true(saved.ok, saved.message)
	assert_eq(saved.simulation.factories().size(), 1, "the import is saved at once")


func test_a_canceled_import_does_not_change_the_game() -> void:
	var main: Control = await _main_with_red_factory()
	var dialog := await _open_export_code_dialog(main)
	var code := (dialog.find_child("ExportCodeText", true, false) as TextEdit).text
	main.find_child("Build_blue", true, false).pressed.emit()

	var confirm := await _import_code(dialog, code)
	confirm.canceled.emit()
	await wait_process_frames(1)

	assert_eq(main.simulation().factories().size(), 2)
	assert_eq(_rows(main).size(), 2)


func test_a_bad_code_shows_the_reason_and_does_not_change_the_game() -> void:
	var main: Control = await _main_with_red_factory()
	var dialog := await _open_export_code_dialog(main)
	var before: Simulation = main.simulation()

	var confirm := await _import_code(dialog, "IR2.abcd.00000000")

	assert_false(confirm.visible, "a bad code does not ask to confirm")
	var message: Label = dialog.find_child("ImportMessage", true, false)
	assert_true(message.visible)
	assert_string_contains(message.text, "your game did not change")
	assert_string_contains(message.text, "checksum does not match")
	assert_same(main.simulation(), before, "the game is the same game")
	assert_eq(main.simulation().factories().size(), 1)
