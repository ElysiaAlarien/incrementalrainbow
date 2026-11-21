class_name ExportCodeDialog
extends AcceptDialog
## Moves the game between devices: it shows the export code of the game to
## copy, and imports a pasted code. It asks the player to confirm before an
## import replaces the game.
##
## It holds no rules: [ExportCode] makes and reads the codes. It emits
## [signal import_confirmed] with the new game, and the screen replaces its
## game with it.

## The player confirmed that the game in the code replaces the current game.
signal import_confirmed(simulation: Simulation)

const HINT_COLOR := Color(0.7, 0.72, 0.8)
const ERROR_COLOR := Color(1, 0.55, 0.45)
const CODE_FIELD_SIZE := Vector2(760, 80)

var _content: Content
var _export_text := TextEdit.new()
var _import_text := TextEdit.new()
var _import_button := Button.new()
var _import_message := Label.new()
var _confirm := ConfirmationDialog.new()
## The game of the code that waits for the player to confirm the import.
var _pending: Simulation


func _init(content: Content) -> void:
	_content = content
	name = "ExportCodeDialog"
	title = "Move your game to another device"
	ok_button_text = "Close"

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 10)
	add_child(layout)

	layout.add_child(_heading("Export code"))
	layout.add_child(_hint("Copy this code, then import it on your other device."))
	_export_text.name = "ExportCodeText"
	_export_text.editable = false
	_setup_code_field(_export_text)
	layout.add_child(_export_text)
	var copy_button := Button.new()
	copy_button.name = "CopyCode"
	copy_button.text = "Copy code"
	copy_button.pressed.connect(func() -> void: DisplayServer.clipboard_set(_export_text.text))
	layout.add_child(_button_row([copy_button]))

	layout.add_child(HSeparator.new())
	layout.add_child(_heading("Import code"))
	layout.add_child(_hint("Paste a code from your other device. Its game replaces your current game."))
	_import_text.name = "ImportCodeText"
	_import_text.placeholder_text = "Paste an export code here."
	_setup_code_field(_import_text)
	_import_text.text_changed.connect(func() -> void: _show_import_message(""))
	layout.add_child(_import_text)
	var paste_button := Button.new()
	paste_button.name = "PasteCode"
	paste_button.text = "Paste"
	paste_button.pressed.connect(_on_paste_pressed)
	_import_button.name = "ImportCode"
	_import_button.text = "Import"
	_import_button.pressed.connect(_on_import_pressed)
	layout.add_child(_button_row([paste_button, _import_button]))

	_import_message.name = "ImportMessage"
	_import_message.add_theme_color_override(&"font_color", ERROR_COLOR)
	_import_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_import_message.custom_minimum_size.x = CODE_FIELD_SIZE.x
	_import_message.visible = false
	layout.add_child(_import_message)

	_confirm.name = "ImportConfirm"
	_confirm.title = "Replace your game?"
	_confirm.dialog_text = "The game in the code replaces your current game.\nYour current game is lost, unless you exported it first."
	_confirm.ok_button_text = "Replace my game"
	_confirm.confirmed.connect(_on_import_confirmed)
	_confirm.canceled.connect(func() -> void: _pending = null)
	add_child(_confirm)


## Shows the dialog with the export code of [param simulation].
func open(simulation: Simulation) -> void:
	_export_text.text = ExportCode.encode(simulation)
	_import_text.text = ""
	_show_import_message("")
	_pending = null
	popup_centered()


func _on_paste_pressed() -> void:
	_import_text.text = DisplayServer.clipboard_get()
	_show_import_message("")


func _on_import_pressed() -> void:
	var result := ExportCode.decode(_content, _import_text.text)
	if not result.ok:
		_pending = null
		_show_import_message("The code did not import, and your game did not change.\n%s" % result.message)
		return
	_show_import_message("")
	_pending = result.simulation
	_confirm.popup_centered()


func _on_import_confirmed() -> void:
	var simulation := _pending
	_pending = null
	if simulation == null:
		return
	hide()
	import_confirmed.emit(simulation)


func _show_import_message(text: String) -> void:
	if _import_message.text == text:
		return
	_import_message.text = text
	_import_message.visible = not text.is_empty()
	# Fit the dialog to its content again, so that it shrinks when the message
	# goes away.
	if visible:
		reset_size()
		move_to_center()


func _setup_code_field(field: TextEdit) -> void:
	field.custom_minimum_size = CODE_FIELD_SIZE
	field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	field.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	field.add_theme_font_size_override(&"font_size", 14)


static func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 24)
	return label


static func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", HINT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = CODE_FIELD_SIZE.x
	return label


static func _button_row(buttons: Array[Button]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	for button in buttons:
		row.add_child(button)
	return row
