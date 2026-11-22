class_name GooglePlayCloudSave
extends CloudSave
## Google Play saved games (snapshots) through the Android singleton of the
## godot-play-game-services plugin. NOT FINISHED: the game does not ship the
## plugin yet, and no one has tested this on a device. See README.md in this
## folder for the steps, and for the parts of the plugin that are not
## verified.
##
## With no plugin, or before the player is signed in to Google Play Games,
## [method is_available] is false and each operation finishes as
## [constant CloudOperation.Status.NOT_AVAILABLE]. The script names no plugin
## class, so it loads with no plugin.
##
## The plugin answers with signals, so each operation finishes later. One read
## and one write can wait at a time.

## The name of the Android singleton of the plugin.
const SINGLETON := &"GodotPlayGameServices"
## The text that Google Play shows with the saved game.
const DESCRIPTION := "Incremental Rainbow"

var _plugin: Object
var _signed_in := false
var _pending_read: CloudOperation
var _pending_write: CloudOperation


func _init() -> void:
	if not Engine.has_singleton(SINGLETON):
		return
	_plugin = Engine.get_singleton(SINGLETON)
	# TODO(#24): check that the plugin is initialized once only, if #25
	# (achievements) also uses it.
	_plugin.call(&"initialize")
	_plugin.connect(&"userAuthenticated", func(is_authenticated: bool) -> void:
		_signed_in = is_authenticated)
	_plugin.connect(&"gameLoaded", _on_game_loaded)
	_plugin.connect(&"gameSaved", _on_game_saved)
	_plugin.connect(&"conflictEmitted", _on_conflict)
	_plugin.call(&"isAuthenticated")


func service_name() -> String:
	return "Google Play"


func is_available() -> bool:
	return _plugin != null and _signed_in


func read() -> CloudOperation:
	if not is_available():
		return CloudOperation.not_available(_not_available_message())
	if _pending_read != null and not _pending_read.is_done():
		return CloudOperation.failed("Google Play is still reading the save.")
	_pending_read = CloudOperation.new()
	var operation := _pending_read
	_plugin.call(&"loadGame", SAVE_NAME, false)
	return operation


func write(text: String) -> CloudOperation:
	if not is_available():
		return CloudOperation.not_available(_not_available_message())
	if _pending_write != null and not _pending_write.is_done():
		return CloudOperation.failed("Google Play is still writing the save.")
	_pending_write = CloudOperation.new()
	var operation := _pending_write
	_plugin.call(&"saveGame", SAVE_NAME, DESCRIPTION, text.to_utf8_buffer(), 0, 0)
	return operation


func _not_available_message() -> String:
	if _plugin == null:
		return "This build has no Google Play Games."
	return "You are not signed in to Google Play Games."


## [param json_data] is the snapshot as JSON, or an empty object when the
## cloud has no save.
func _on_game_loaded(json_data: String) -> void:
	if _pending_read == null:
		return
	var json := JSON.new()
	if json.parse(json_data) != OK:
		_pending_read.fail(CloudOperation.Status.FAILED, "Google Play gave a save that is not valid JSON.")
		return
	var data: Variant = json.data
	if not data is Dictionary or data.is_empty():
		_pending_read.succeed("")
		return
	var bytes := _bytes(data.get("content"))
	if bytes.is_empty():
		_pending_read.fail(CloudOperation.Status.FAILED, "Google Play gave a save with no data.")
		return
	_pending_read.succeed(bytes.get_string_from_utf8())


func _on_game_saved(is_saved: bool, _save_data_name: String, _description: String) -> void:
	if _pending_write == null:
		return
	if is_saved:
		_pending_write.succeed()
	else:
		_pending_write.fail(CloudOperation.Status.FAILED, "Google Play did not save the game.")


## Google Play found two versions of the snapshot. The game makes its own
## choice (ADR-0018), so the operation fails, and the next sync tries again.
func _on_conflict(_json_data: String) -> void:
	for operation: CloudOperation in [_pending_read, _pending_write]:
		if operation != null:
			operation.fail(CloudOperation.Status.FAILED, "Google Play has two versions of the save.")


## The bytes of the snapshot content in the JSON of the plugin. NOT VERIFIED:
## the plugin can send them as an array of numbers or as base64 text.
static func _bytes(content: Variant) -> PackedByteArray:
	if content is Array:
		return PackedByteArray(content)
	if content is String:
		return Marshalls.base64_to_raw(content)
	return PackedByteArray()
