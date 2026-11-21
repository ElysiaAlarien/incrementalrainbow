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
