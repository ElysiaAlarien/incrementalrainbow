extends GutTest
## Smoke tests: the main screen fits landscape screens of phones, tablets, and
## computers, with no cut-off text and with touch targets large enough to
## touch, and its actions work with a mouse and with touch.
##
## Each test runs the screen in a viewport of the logical size that [UiScale]
## gives a real device (see [DeviceProfiles]), with a game that fills the
## screen as much as a real game can (see [LayoutGame]).

const MainScene := preload("res://src/ui/main.tscn")
## A save path of its own, so that tests never touch the player's save.
const SAVE_PATH := "user://test_saves/layout.json"
## The device clock of the tests, the time of the save, so that there is no
## time away.
const SAVED_AT_UNIX_MS := 1_795_000_000_000
## Rounding of the layout, in logical pixels.
const EPSILON := 0.5
## The smallest touch target on a phone or a tablet, in millimeters. 44 dp is
## about 7 mm.
const MIN_TOUCH_MM := 6.8

var _viewport: SubViewport
## The save text of [LayoutGame], made once.
var _save_text: String


func before_all() -> void:
	_save_text = LayoutGame.save_text(SAVED_AT_UNIX_MS)
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())


func after_all() -> void:
	_remove_save()


func _remove_save() -> void:
	for path in [SAVE_PATH, SAVE_PATH + SaveFile.TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Opens the screen in a viewport of [param size] logical pixels, with a new
## copy of the game, so that a save of an earlier screen does not change it.
func _open_main(size: Vector2) -> Control:
	_remove_save()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(_save_text)
	file.close()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(size)
	_viewport.gui_embed_subwindows = true
	add_child_autofree(_viewport)
	var main: Control = MainScene.instantiate()
	main.save_path = SAVE_PATH
	main.clock = func() -> int: return SAVED_AT_UNIX_MS
	_viewport.add_child(main)
	main.set_process(false)
	await wait_process_frames(2)
	return main


func _close(main: Control) -> void:
	_viewport.remove_child(main)
	main.free()


func test_the_layout_game_fills_the_screen() -> void:
	var main := await _open_main(Vector2(1280, 720))
	var sim: Simulation = main.simulation()
	assert_eq(sim.buildable_factory_colors().size(), Content.load_dir(Content.DEFAULT_DIR).colors().size(),
		"all colors are unlocked")
	assert_gt(sim.warehouses().size(), 1)
	assert_gt(sim.links().size(), 6)
	assert_false(sim.demand_events().is_empty(), "a demand event is active")
	assert_true(sim.guided_start().is_active(), "the guide shows")
	assert_true(sim.links().any(func(view: LinkView) -> bool: return view.vehicle != sim.transport_tier().id),
		"a vehicle can upgrade")
	assert_true(sim.warehouses().any(func(view: WarehouseView) -> bool: return view.holds()),
		"a warehouse holds")
	_close(main)


func test_each_section_fits_each_device() -> void:
	for profile in DeviceProfiles.all():
		var size := profile.logical_size()
		var main := await _open_main(size)
		_show_long_message(main)
		var smallest := INF
		for section: StringName in main.SECTIONS:
			main.show_section(section)
			await wait_process_frames(2)
			_assert_fits(main, size, "%s, %s" % [profile.name, section])
			for control in _pressables(main):
				smallest = minf(smallest, minf(control.size.x, control.size.y))
		# A screen below the smallest logical size has a smaller scale, so its
		# touch targets are smaller too.
		if profile.mobile and not profile.is_below_floor():
			assert_gte(profile.millimeters(smallest), MIN_TOUCH_MM,
				"%s: the smallest touch target is about 7 mm" % profile.name)
		_close(main)


## Shows the reason of a failed command, which makes the top of the screen
## as tall as it can be: a link from a warehouse to a warehouse.
func _show_long_message(main: Control) -> void:
	for choice_name: String in ["NewLinkSource", "NewLinkDestination"]:
		var choice: OptionButton = main.find_child(choice_name, true, false)
		for i in choice.item_count:
			if choice.get_item_metadata(i)[0] == &"warehouse":
				choice.select(i)
				break
	main.find_child("MakeLink", true, false).pressed.emit()
	assert_true((main.find_child("MessageLabel", true, false) as Control).visible, "a message shows")


func test_each_dialog_fits_each_device() -> void:
	for profile in DeviceProfiles.all():
		var size := profile.logical_size()
		var main := await _open_main(size)
		var where := profile.name

		main.find_child("ExportCodeButton", true, false).pressed.emit()
		await wait_process_frames(2)
		var export_dialog: ExportCodeDialog = main.find_child("ExportCodeDialog", true, false)
		_assert_dialog_fits(export_dialog, size, "%s, export" % where)
		# A code that imports asks the player to confirm.
		(export_dialog.find_child("ImportCodeText", true, false) as TextEdit).text = \
			(export_dialog.find_child("ExportCodeText", true, false) as TextEdit).text
		export_dialog.find_child("ImportCode", true, false).pressed.emit()
		await wait_process_frames(2)
		var import_confirm: ConfirmationDialog = export_dialog.find_child("ImportConfirm", true, false)
		_assert_dialog_fits(import_confirm, size, "%s, import" % where)
		import_confirm.hide()
		export_dialog.hide()

		main.find_child("PrestigeButton", true, false).pressed.emit()
		await wait_process_frames(2)
		var confirm: ConfirmationDialog = main.find_child("PrestigeConfirm", true, false)
		_assert_dialog_fits(confirm, size, "%s, prestige" % where)
		confirm.hide()

		var summary_dialog: OfflineSummaryDialog = main.find_child("OfflineSummaryDialog", true, false)
		var summary := OfflineSummary.new()
		summary.duration_ms = 86_400_000
		summary.skipped_ms = 3 * 86_400_000
		summary.money_earned = BigNumber.from_int(LayoutGame.MONEY)
		summary_dialog.show_summary(summary, 86_400_000)
		await wait_process_frames(2)
		_assert_dialog_fits(summary_dialog, size, "%s, summary" % where)
		summary_dialog.hide()
		_close(main)


func test_the_title_shows_only_when_money_and_prisms_have_room() -> void:
	var wide := await _open_main(DeviceProfiles.named("1080p monitor").logical_size())
	assert_true((wide.find_child("Title", true, false) as Control).visible, "a wide screen has room")
	_close(wide)
	var narrow := await _open_main(DeviceProfiles.named("small phone").logical_size())
	assert_false((narrow.find_child("Title", true, false) as Control).visible, "a small phone has no room")
	assert_true((narrow.find_child("MoneyLabel", true, false) as Control).is_visible_in_tree())
	_close(narrow)


func test_a_mouse_click_builds_a_factory() -> void:
	var main := await _open_main(DeviceProfiles.named("1080p monitor").logical_size())
	var before: int = main.simulation().factories().size()
	var button: Button = main.find_child("Build_red", true, false)

	_click(_center(button))
	await wait_process_frames(1)

	assert_eq(main.simulation().factories().size(), before + 1)
	_close(main)


func test_a_tap_on_a_phone_builds_one_factory() -> void:
	var main := await _open_main(DeviceProfiles.named("phone").logical_size())
	var before: int = main.simulation().factories().size()
	var button: Button = main.find_child("Build_red", true, false)

	_tap(_center(button))
	await wait_process_frames(1)

	assert_eq(main.simulation().factories().size(), before + 1, "one tap, one factory")
	_close(main)


func test_a_tap_on_the_rail_opens_a_section() -> void:
	var main := await _open_main(DeviceProfiles.named("small phone").logical_size())

	_tap(_center(main.find_child("Rail_links", true, false)))
	await wait_process_frames(1)

	assert_eq(main.current_section(), &"links")
	assert_true((main.find_child("LinkList", true, false) as Control).is_visible_in_tree())
	assert_false((main.find_child("ColorCards", true, false) as Control).is_visible_in_tree())
	_close(main)


func test_the_mouse_wheel_scrolls_a_section() -> void:
	var main := await _open_main(DeviceProfiles.named("720p window").logical_size())
	var scroll: ScrollContainer = main.find_child("Scroll", true, false)
	var at := _center(scroll)
	for pressed in [true, false]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.position = at
		wheel.global_position = at
		wheel.pressed = pressed
		wheel.factor = 1.0
		_viewport.push_input(wheel)
	await wait_process_frames(2)

	assert_gt(scroll.scroll_vertical, 0, "the colors scrolled down")
	_close(main)


func test_a_tap_steps_a_sell_threshold() -> void:
	var main := await _open_main(DeviceProfiles.named("phone").logical_size())
	main.show_section(&"factories")
	await wait_process_frames(2)
	var row: WarehouseRow = main.find_child("Warehouse1", true, false)
	var stepper: NumberStepper = row.find_child("SellThresholdStepper", true, false)
	(main.find_child("Scroll", true, false) as ScrollContainer).ensure_control_visible(stepper)
	await wait_process_frames(2)
	var before := row.threshold_box().value

	_tap(_center(stepper.down_button()))
	await wait_process_frames(1)

	assert_eq(row.threshold_box().value, before - 1)
	_close(main)


func test_a_click_opens_the_list_of_a_choice() -> void:
	var main := await _open_main(DeviceProfiles.named("1080p monitor").logical_size())
	main.show_section(&"links")
	await wait_process_frames(2)
	var choice: OptionButton = main.find_child("NewLinkSource", true, false)

	_click(_center(choice))
	await wait_process_frames(2)

	assert_true(choice.get_popup().visible, "the list shows")
	choice.get_popup().hide()
	_close(main)


func test_each_item_of_a_list_is_large_enough_to_touch() -> void:
	var main := await _open_main(DeviceProfiles.named("small phone").logical_size())
	var popup := (main.find_child("NewLinkSource", true, false) as OptionButton).get_popup()
	var font := popup.get_theme_font(&"font")
	var item_height := font.get_height(popup.get_theme_font_size(&"font_size")) \
		+ popup.get_theme_constant(&"v_separation")
	assert_gte(item_height, UiScale.MIN_TOUCH_TARGET)
	_close(main)


func test_a_drag_on_a_phone_scrolls_and_does_not_press() -> void:
	# A phone has a touch screen, and a scroll container drags only there.
	Input.emulate_touch_from_mouse = true
	var main := await _open_main(DeviceProfiles.named("phone").logical_size())
	var before: int = main.simulation().factories().size()
	var scroll: ScrollContainer = main.find_child("Scroll", true, false)
	var start := _center(main.find_child("Build_red", true, false))

	_drag(start, Vector2(0, -200))
	await wait_process_frames(2)

	Input.emulate_touch_from_mouse = false
	assert_gt(scroll.scroll_vertical, 100, "the colors scrolled with the finger")
	assert_eq(main.simulation().factories().size(), before, "the drag did not build")
	_close(main)


func test_symbols_on_buttons_are_vector_art() -> void:
	var main := await _open_main(Vector2(1280, 720))
	var color: OptionButton = main.find_child("NewWarehouseColor", true, false)
	for i in color.item_count:
		assert_is(color.get_item_icon(i), DPITexture, color.get_item_text(i))
	_close(main)


## Checks that the screen fits [param size]: no control past the edges of the
## screen, no cut-off text, and each control that the player presses is large
## enough to touch.
func _assert_fits(main: Control, size: Vector2, where: String) -> void:
	assert_lte(main.get_combined_minimum_size().x, size.x + EPSILON, "%s: the screen fits the width" % where)
	assert_lte(main.get_combined_minimum_size().y, size.y + EPSILON, "%s: the screen fits the height" % where)
	var checked := 0
	for control in _visible_controls(main):
		checked += 1
		var rect := control.get_global_rect()
		if rect.position.x < -EPSILON or rect.end.x > size.x + EPSILON:
			fail_test("%s: %s is past the edge of the screen: %s" % [where, control.get_path(), rect])
		if control is Label:
			_assert_text_shows(control as Label, where)
		if control is Button:
			var button := control as Button
			if button.clip_text or button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
				fail_test("%s: %s cuts its text" % [where, button.get_path()])
	for control in _pressables(main):
		if control.size.x < UiScale.MIN_TOUCH_TARGET - EPSILON or control.size.y < UiScale.MIN_TOUCH_TARGET - EPSILON:
			fail_test("%s: %s is %s, too small to touch" % [where, control.get_path(), control.size])
	assert_gt(checked, 20, "%s: the check saw the controls" % where)


## Checks that [param label] shows all its text.
func _assert_text_shows(label: Label, where: String) -> void:
	if label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		fail_test("%s: %s cuts its text" % [where, label.get_path()])
	elif label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var width := label.get_theme_font(&"font").get_multiline_string_size(label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
		if width > label.size.x + EPSILON:
			fail_test("%s: %s is %d wide for its text of %d" % [where, label.get_path(), label.size.x, width])
	elif label.get_line_count() > label.get_visible_line_count():
		fail_test("%s: %s shows %d of %d lines" % [where, label.get_path(), label.get_visible_line_count(),
			label.get_line_count()])


## Checks that [param dialog] is inside the screen with its title bar, and
## that its text shows.
func _assert_dialog_fits(dialog: AcceptDialog, size: Vector2, where: String) -> void:
	assert_true(dialog.visible, "%s: the dialog shows" % where)
	var title := float(dialog.get_theme_constant(&"title_height"))
	var rect := Rect2(Vector2(dialog.position) - Vector2(0, title), Vector2(dialog.size) + Vector2(0, title))
	assert_true(Rect2(Vector2.ZERO, size).encloses(rect), "%s: the dialog %s is inside the screen %s" % [
		where, rect, size])
	var close_size := float(dialog.get_theme_constant(&"title_height"))
	assert_gte(close_size, UiScale.MIN_TOUCH_TARGET - EPSILON, "%s: the title bar with the close button" % where)
	for control in dialog.find_children("*", "Control", true, false):
		var item := control as Control
		if not item.is_visible_in_tree() or item.get_viewport() != dialog:
			continue
		if item is Label:
			_assert_text_shows(item as Label, where)
		if item is BaseButton and (item.size.x < UiScale.MIN_TOUCH_TARGET - EPSILON
				or item.size.y < UiScale.MIN_TOUCH_TARGET - EPSILON):
			fail_test("%s: %s is %s, too small to touch" % [where, item.get_path(), item.size])


## The controls of the screen that show now, not those in a dialog.
func _visible_controls(main: Control) -> Array[Control]:
	var result: Array[Control] = []
	for node in main.find_children("*", "Control", true, false):
		var control := node as Control
		if control.get_viewport() == _viewport and control.is_visible_in_tree():
			result.append(control)
	return result


## The controls of the screen that the player presses and that show now.
func _pressables(main: Control) -> Array[Control]:
	var result: Array[Control] = []
	for control in _visible_controls(main):
		if control is BaseButton or control is LineEdit:
			result.append(control)
	return result


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## A mouse click at [param at], as a computer sends it.
func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_viewport.push_input(motion)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		click.pressed = pressed
		_viewport.push_input(click)


## A finger that moves by [param by] from [param at], as a phone sends it:
## touch events, and the mouse events that Godot makes from them.
func _drag(at: Vector2, by: Vector2) -> void:
	_pointer(at, true, Vector2.ZERO)
	const STEPS := 10
	for i in STEPS:
		_pointer(at + by * (i + 1) / STEPS, true, by / STEPS)
	_pointer(at + by, false, Vector2.ZERO)


## One event of a finger at [param at]: a press, a move when [param moved] is
## not zero, or a release when [param down] is false.
func _pointer(at: Vector2, down: bool, moved: Vector2) -> void:
	if moved != Vector2.ZERO:
		var motion := InputEventMouseMotion.new()
		motion.device = InputEvent.DEVICE_ID_EMULATION
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = at
		motion.global_position = at
		motion.relative = moved
		_viewport.push_input(motion)
		var drag := InputEventScreenDrag.new()
		drag.position = at
		drag.relative = moved
		_viewport.push_input(drag)
		return
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	emulated.position = at
	emulated.global_position = at
	emulated.pressed = down
	_viewport.push_input(emulated)
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = down
	_viewport.push_input(touch)


## A tap at [param at], as a phone sends it: a touch, and the mouse click that
## Godot makes from it (input_devices/pointing/emulate_mouse_from_touch).
func _tap(at: Vector2) -> void:
	_pointer(at, true, Vector2.ZERO)
	_pointer(at, false, Vector2.ZERO)
