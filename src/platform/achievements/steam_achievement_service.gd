class_name SteamAchievementService
extends AchievementService
## The Steam adapter, for the GodotSteam GDExtension. The names are checked
## against the source of GodotSteam 4.24, but no one ran it with Steam yet.
## docs/achievements.md says what a person must do to finish it.
##
## It names no GodotSteam class, so the script parses in a build with no
## GodotSteam. It calls the methods of the singleton by name.
## [method AchievementServices.for_this_device] gives it the singleton from
## [method PlatformSdks.steam], which starts Steam once for the achievements
## and the cloud save.

var _steam: Object


## [param steam] is the GodotSteam singleton after a good start, or null for
## a build with no Steam.
func _init(steam: Object = null) -> void:
	_steam = steam


func platform() -> StringName:
	return &"steam"


func has_sdk() -> bool:
	return _steam != null


## Steam started, so achievements work, also when the Steam client is offline.
func is_available() -> bool:
	return _steam != null


## Steam keeps the unlock on the device after [code]storeStats()[/code], and
## sends it when it is online again. [code]setAchievement[/code] is false when
## the app has no achievement with this API name in Steamworks.
func unlock(def: AchievementDef) -> bool:
	var api_name := def.platform_id(platform())
	if _steam == null or api_name.is_empty():
		return false
	if not _steam.call(&"setAchievement", api_name):
		push_warning("Steam has no achievement %s." % api_name)
		return false
	_steam.call(&"storeStats")
	return true


## Runs the Steam callbacks. It is necessary only when GodotSteam started
## itself with no embedded callbacks. Else it does nothing (see
## [method PlatformSdks.start_steam]).
func poll() -> void:
	if _steam != null:
		_steam.call(&"run_callbacks")
