class_name GooglePlayCloudSave
extends CloudSave
## Google Play saved games (snapshots) through the Android singleton of the
## godot-play-game-services plugin (v3.4.0). The calls follow the plugin
## source, and unit tests check them with a fake. No one has tested this on a
## device yet. See README.md in this folder for the steps and the limits of
## the plugin.
##
## With no plugin, or when the player is not signed in to Google Play Games,
## [method is_available] is false and each operation finishes as
## [constant CloudOperation.Status.NOT_AVAILABLE]. The script names no plugin
## class, so it loads with no plugin.
##
## The plugin answers with signals, so each operation finishes later. The
## answer to the sign-in check also comes later: an operation before it waits
## for it. While the player is signed out, each operation asks again. One read and one write can wait at a time. The plugin sends no
## signal for most errors, so such an operation fails only at the timeout of
## [method CloudOperation.wait].

## The name of the Android singleton of the plugin.
const SINGLETON := &"GodotPlayGameServices"
## The start of the text that Google Play shows with the saved game.
const DESCRIPTION := "Incremental Rainbow"

## Gives the local date and time of a write, for the text of the saved game.
## Tests replace it.
var clock: Callable = func() -> String: return Time.get_datetime_string_from_system(false, true)

enum SignIn {
	## The plugin did not answer the sign-in check yet.
	UNKNOWN,
	SIGNED_IN,
	SIGNED_OUT,
}

var _plugin: Object
var _sign_in := SignIn.UNKNOWN
## The starts of the operations that wait for the sign-in answer.
var _waiting: Array[Callable] = []
var _pending_read: CloudOperation
var _pending_write: CloudOperation
## The text of the saved game of [member _pending_write]. The answer of the
## plugin has it, so an answer to an earlier write does not finish this one.
var _pending_write_description := ""


## [param plugin] is the plugin singleton, or a fake in tests. Null finds the
## singleton, if the build has one.
func _init(plugin: Object = null) -> void:
	_plugin = plugin if plugin != null else _find_singleton()
	if _plugin == null:
		return
	_plugin.connect(&"userAuthenticated", _on_user_authenticated)
	_plugin.connect(&"gameLoaded", _on_game_loaded)
	_plugin.connect(&"gameSaved", _on_game_saved)
	_plugin.connect(&"conflictEmitted", _on_conflict)
	# The achievements of #25 can also start the plugin. Whether a second
	# start is safe is on the device checklist in README.md.
	_plugin.call(&"initialize")
	# The answer comes later, with the signal userAuthenticated.
	_plugin.call(&"isAuthenticated")


func service_name() -> String:
	return "Google Play"


func is_available() -> bool:
	return _plugin != null and _sign_in == SignIn.SIGNED_IN


func read() -> CloudOperation:
	var operation := CloudOperation.new()
	_when_signed_in(operation, _start_read)
	return operation


func write(text: String) -> CloudOperation:
	var operation := CloudOperation.new()
	_when_signed_in(operation, _start_write.bind(text))
	return operation


func _not_available_message() -> String:
	if _plugin == null:
		return "This build has no Google Play Games."
	return "You are not signed in to Google Play Games."


## Starts [param operation] with [param start] when the player is signed in,
## or after the answer to the sign-in check. When the player was signed out,
## it asks again first, because only a check or a sign-in sends the answer:
## the player can sign in after the start, for example in another game. With
## [param may_ask] false, a player who is signed out fails the operation.
func _when_signed_in(operation: CloudOperation, start: Callable, may_ask: bool = true) -> void:
	if _plugin != null and _sign_in == SignIn.SIGNED_OUT and may_ask:
		_sign_in = SignIn.UNKNOWN
		_plugin.call(&"isAuthenticated")
	if _plugin != null and _sign_in == SignIn.UNKNOWN:
		_waiting.append(func() -> void:
			# An operation that timed out does not start.
			if not operation.is_done():
				_when_signed_in(operation, start, false))
	elif not is_available():
		operation.fail(CloudOperation.Status.NOT_AVAILABLE, _not_available_message())
	else:
		start.call(operation)


func _start_read(operation: CloudOperation) -> void:
	if _pending_read != null and not _pending_read.is_done():
		operation.fail(CloudOperation.Status.FAILED, "Google Play is still reading the save.")
		return
	_pending_read = operation
	_plugin.call(&"loadGame", SAVE_NAME, false)


func _start_write(operation: CloudOperation, text: String) -> void:
	if _pending_write != null and not _pending_write.is_done():
		operation.fail(CloudOperation.Status.FAILED, "Google Play is still writing the save.")
		return
	_pending_write = operation
	# A late answer to an earlier write has an earlier time: that write
	# started at least one timeout before this one.
	_pending_write_description = "%s, saved %s" % [DESCRIPTION, clock.call()]
	# The played time and the progress are 0: the game makes its own choice in
	# a conflict (ADR-0018).
	_plugin.call(&"saveGame", SAVE_NAME, _pending_write_description, text.to_utf8_buffer(), 0, 0)


func _on_user_authenticated(is_authenticated: bool) -> void:
	_sign_in = SignIn.SIGNED_IN if is_authenticated else SignIn.SIGNED_OUT
	var waiting := _waiting
	_waiting = []
	for start in waiting:
		start.call()


## [param json_data] is the snapshot as JSON, or "null" when the cloud has no
## snapshot of that name.
func _on_game_loaded(json_data: String) -> void:
	if _pending_read == null or _pending_read.is_done():
		return
	var json := JSON.new()
	if json.parse(json_data) != OK:
		_pending_read.fail(CloudOperation.Status.FAILED, "Google Play gave a save that is not valid JSON.")
		return
	var data: Variant = json.data
	if data == null:
		_pending_read.succeed("")
		return
	if not data is Dictionary:
		_pending_read.fail(CloudOperation.Status.FAILED, "Google Play gave a save that the game cannot read.")
		return
	var metadata: Variant = data.get("metadata")
	if not metadata is Dictionary or metadata.get("uniqueName") != SAVE_NAME:
		# Another saved game, for example one that the player picked in a
		# screen of the plugin.
		return
	var bytes: Variant = _bytes(data.get("content"))
	if bytes == null:
		_pending_read.fail(CloudOperation.Status.FAILED, "Google Play gave a save with no data.")
		return
	_pending_read.succeed((bytes as PackedByteArray).get_string_from_utf8())


func _on_game_saved(is_saved: bool, save_data_name: String, description: String) -> void:
	if _pending_write == null or save_data_name != SAVE_NAME \
			or description != _pending_write_description:
		return
	if is_saved:
		_pending_write.succeed()
	else:
		_pending_write.fail(CloudOperation.Status.FAILED, "Google Play did not save the game.")


## Google Play found two versions of the snapshot. This is rare, because the
## plugin sets a resolution policy of Google. The game makes its own choice
## (ADR-0018). Thus the operation of the conflict fails, and the next sync
## tries again. The JSON has the "origin" of the conflict: "SAVE" or "LOAD".
func _on_conflict(json_data: String) -> void:
	var data: Variant = JSON.parse_string(json_data)
	var origin: Variant = data.get("origin") if data is Dictionary else null
	var operations: Array[CloudOperation] = []
	if origin != "LOAD":
		operations.append(_pending_write)
	if origin != "SAVE":
		operations.append(_pending_read)
	for operation in operations:
		if operation != null:
			operation.fail(CloudOperation.Status.FAILED, "Google Play has two versions of the save.")


## The bytes of the snapshot content in the JSON of the plugin, or null. Gson
## writes a byte array as an array of numbers from -128 to 127.
static func _bytes(content: Variant) -> Variant:
	if not content is Array:
		return null
	for value: Variant in content:
		if not (value is float or value is int):
			return null
	# Each number becomes its low byte, so -1 becomes 255.
	return PackedByteArray(content)


static func _find_singleton() -> Object:
	return Engine.get_singleton(SINGLETON) if Engine.has_singleton(SINGLETON) else null
