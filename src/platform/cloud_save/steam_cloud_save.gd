class_name SteamCloudSave
extends CloudSave
## Steam Cloud through the Steam Remote Storage API of the GodotSteam
## GDExtension. NOT FINISHED: the game does not ship GodotSteam yet, and no
## one has tested this on Steam. See README.md in this folder for the steps.
##
## With no GodotSteam, with Steam not started, or with Steam Cloud off for the
## player or the game, [method is_available] is false and each operation
## finishes as [constant CloudOperation.Status.NOT_AVAILABLE]. The script names
## no GodotSteam class, so it loads with no plugin.

## The name of the engine singleton of GodotSteam.
const SINGLETON := &"Steam"


func service_name() -> String:
	return "Steam Cloud"


func is_available() -> bool:
	var steam := _steam()
	return steam != null and steam.call(&"isCloudEnabledForAccount") \
		and steam.call(&"isCloudEnabledForApp")


func read() -> CloudOperation:
	if not is_available():
		return CloudOperation.not_available(_not_available_message())
	var steam := _steam()
	if not steam.call(&"fileExists", SAVE_NAME):
		return CloudOperation.done("")
	var size: int = steam.call(&"getFileSize", SAVE_NAME)
	if size <= 0:
		return CloudOperation.failed("Steam Cloud gave no size for the save.")
	var data: Variant = steam.call(&"fileRead", SAVE_NAME, size)
	if not data is Dictionary or data.get("ret") != size or not data.get("buf") is PackedByteArray:
		return CloudOperation.failed("Steam Cloud did not read the whole save.")
	return CloudOperation.done((data.buf as PackedByteArray).get_string_from_utf8())


func write(text: String) -> CloudOperation:
	if not is_available():
		return CloudOperation.not_available(_not_available_message())
	if not _steam().call(&"fileWrite", SAVE_NAME, text.to_utf8_buffer()):
		return CloudOperation.failed("Steam Cloud did not write the save. Its space can be full.")
	return CloudOperation.done()


func _not_available_message() -> String:
	if _steam() == null:
		return "This build has no Steam."
	return "Steam Cloud is off for this game or this account."


static func _steam() -> Object:
	return Engine.get_singleton(SINGLETON) if Engine.has_singleton(SINGLETON) else null
