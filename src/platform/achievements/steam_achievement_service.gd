class_name SteamAchievementService
extends AchievementService
## The Steam adapter, for the GodotSteam extension. SKELETON: no one has run it
## with Steam yet. docs/achievements.md says what a person must do to finish it.
##
## It names no GodotSteam class or method in the code, so that the script
## parses in a build with no GodotSteam. It finds the [code]Steam[/code]
## engine singleton at run time and calls its methods by name. With no
## singleton, or with a method that is not there, it does nothing.
##
## NOT VERIFIED: the method names below are from the GodotSteam documentation
## for Godot 4, not from a test. Check them against the GodotSteam version
## that the build uses.

const SINGLETON := &"Steam"

var _steam: Object = null
var _started := false


func _init() -> void:
	if Engine.has_singleton(SINGLETON):
		_steam = Engine.get_singleton(SINGLETON)
		_started = _start()


func platform() -> StringName:
	return &"steam"


func has_sdk() -> bool:
	return _steam != null


func is_available() -> bool:
	return _started


func unlock(def: AchievementDef) -> bool:
	var api_name := def.platform_id(platform())
	if not _started or api_name.is_empty() or not _steam.has_method(&"setAchievement"):
		return false
	_steam.call(&"setAchievement", api_name)
	# Steam keeps the change on the device until a store, and sends it when it
	# is online again.
	if _steam.has_method(&"storeStats"):
		_steam.call(&"storeStats")
	return true


func poll() -> void:
	if _started and _steam.has_method(&"run_callbacks"):
		_steam.call(&"run_callbacks")


## Starts the Steam API. Returns true when Steam runs and the user is signed
## in. NOT VERIFIED: GodotSteam 4 returns a Dictionary with "status" 0 for
## success.
func _start() -> bool:
	if not _steam.has_method(&"steamInitEx"):
		return false
	var result: Variant = _steam.call(&"steamInitEx")
	return result is Dictionary and result.get("status", -1) == 0
