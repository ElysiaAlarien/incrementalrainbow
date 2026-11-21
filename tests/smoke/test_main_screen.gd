extends GutTest
## Smoke test: the main screen loads, builds a factory, and shows it.

const MainScene := preload("res://src/ui/main.tscn")


func test_building_a_factory_shows_it_on_the_screen() -> void:
	var main: Control = add_child_autofree(MainScene.instantiate())
	await wait_process_frames(1)

	var button: Button = main.find_child("Build_red", true, false)
	assert_not_null(button, "a build button for red")
	assert_not_null(button.icon, "the button shows the red symbol")
	button.pressed.emit()
	main.simulation().tick(60_000)
	await wait_process_frames(1)

	var rows := main.find_children("Factory*", "FactoryRow", true, false)
	assert_eq(rows.size(), 1)
	var row: FactoryRow = rows[0]
	assert_eq(row.bay_text(), "Output bay: 10 / 10")
	assert_eq(row.status_text(), "Stopped: output bay full")
	assert_false(main.find_child("EmptyLabel", true, false).visible)


## The main screen with one red factory built.
func _main_with_red_factory() -> Control:
	var main: Control = add_child_autofree(MainScene.instantiate())
	await wait_process_frames(1)
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
