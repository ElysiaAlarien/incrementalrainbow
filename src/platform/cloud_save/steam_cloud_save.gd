class_name SteamCloudSave
extends CloudSave
## Steam Cloud through the Steam Remote Storage API of the GodotSteam
## GDExtension (v4.24). The calls follow the GodotSteam source, and unit tests
## check them with a fake. No one has tested this on Steam yet. See README.md
## in this folder for the steps.
##
## This adapter never starts Steam. It uses Steam only after a start that
## worked ([code]get_steam_init_result()[/code] has the status 0), because
## each Remote Storage call before a start logs an engine error. Only
## [code]steamInitEx[/code] sets that result, also when the project setting
## of GodotSteam starts Steam. [code]steamInit[/code] does not, so do not
## start Steam with it.
##
## With no GodotSteam, with Steam not started, or with Steam Cloud off for the
## player or the game, [method is_available] is false and each operation
## finishes as [constant CloudOperation.Status.NOT_AVAILABLE]. The script names no
## GodotSteam class, so it loads with no plugin.
##
## Each operation finishes at once. [code]fileWrite[/code] writes the local
## copy of Steam, and the Steam client uploads it later (also after the game
## quits).

## The name of the engine singleton of GodotSteam.
const SINGLETON := &"Steam"
## The status of [code]steamInitEx[/code] for a start that worked
## (STEAM_API_INIT_RESULT_OK).
const INIT_OK := 0

var _steam: Object


## [param steam] is the GodotSteam singleton, or a fake in tests. Null finds
## the singleton, if the build has one.
func _init(steam: Object = null) -> void:
	_steam = steam if steam != null else _find_singleton()


func service_name() -> String:
	return "Steam Cloud"


func is_available() -> bool:
	return _is_started() and _steam.call(&"isCloudEnabledForAccount") \
		and _steam.call(&"isCloudEnabledForApp")


func read() -> CloudOperation:
	if not is_available():
		return CloudOperation.not_available(_not_available_message())
	if not _steam.call(&"fileExists", SAVE_NAME):
		return CloudOperation.done("")
	var size: int = _steam.call(&"getFileSize", SAVE_NAME)
	if size == 0:
		# An empty file is no save, so that a sync can write over it.
		return CloudOperation.done("")
	if size < 0:
		return CloudOperation.failed("Steam Cloud gave no size for the save.")
	var data: Variant = _steam.call(&"fileRead", SAVE_NAME, size)
	# "ret" is the count of bytes that Steam read, or false with no Remote
	# Storage.
	if not data is Dictionary or not data.get("ret") is int or data.ret != size \
			or not data.get("buf") is PackedByteArray:
		return CloudOperation.failed("Steam Cloud did not read the whole save.")
	return CloudOperation.done((data.buf as PackedByteArray).get_string_from_utf8())


func write(text: String) -> CloudOperation:
	if not is_available():
		return CloudOperation.not_available(_not_available_message())
	if not _steam.call(&"fileWrite", SAVE_NAME, text.to_utf8_buffer()):
		return CloudOperation.failed("Steam Cloud did not write the save. Its space can be full.")
	return CloudOperation.done()


func _not_available_message() -> String:
	if _steam == null:
		return "This build has no Steam."
	if not _is_started():
		return "Steam is not running, or you are not signed in to Steam."
	return "Steam Cloud is off for this game or this account."


func _is_started() -> bool:
	if _steam == null:
		return false
	var result: Variant = _steam.call(&"get_steam_init_result")
	return result is Dictionary and result.get("status") == INIT_OK


static func _find_singleton() -> Object:
	return Engine.get_singleton(SINGLETON) if Engine.has_singleton(SINGLETON) else null
