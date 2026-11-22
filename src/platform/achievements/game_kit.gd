class_name GameKit
extends RefCounted
## The part of Game Center that the achievements use, through the
## GodotApplePlugins GDExtension (its Game Center addon). The names are checked
## against its source at commit a66f619 (2026-10-21), but no one ran it on a
## device yet.
##
## The plugin has ClassDB classes, not an engine singleton. This script names
## no plugin class, so it parses in a build with no plugin.
## Tests give [GameCenterAchievementService] a subclass with no plugin.

## The sign-in result. The plugin sends it again when the player signs in or
## out later.
signal authentication_result(status: bool)
## The sign-in failed, with the text of the error.
signal authentication_error(message: String)

const MANAGER_CLASS := &"GameCenterManager"
const ACHIEVEMENT_CLASS := &"GKAchievement"

## The plugin's GameCenterManager. Keep it: its signals stop when it is freed.
var _manager: Object


## A [GameKit], or null when the build has no Game Center addon of
## GodotApplePlugins.
static func for_this_build() -> GameKit:
	if not ClassDB.class_exists(MANAGER_CLASS) or not ClassDB.class_exists(ACHIEVEMENT_CLASS):
		return null
	return GameKit.new(ClassDB.instantiate(MANAGER_CLASS))


## [param manager] is the plugin's GameCenterManager, or null for a subclass
## with no plugin.
func _init(manager: Object = null) -> void:
	_manager = manager
	if _manager == null:
		return
	_manager.connect(&"authentication_result", authentication_result.emit)
	_manager.connect(&"authentication_error", authentication_error.emit)


## Starts the sign-in. iOS can show its sign-in view. The result comes with
## [signal authentication_result].
func authenticate() -> void:
	_manager.call(&"authenticate")


## Reports the achievement [param achievement_id] as complete, with the
## banner of Game Center. [param done] gets null when it worked, or the error
## (a GKError object) when it did not. It can come from another thread.
func report(achievement_id: String, done: Callable) -> void:
	var achievement: Object = ClassDB.class_call_static(ACHIEVEMENT_CLASS, &"make", achievement_id)
	achievement.set(&"percent_complete", 100.0)
	achievement.set(&"shows_completion_banner", true)
	ClassDB.class_call_static(ACHIEVEMENT_CLASS, &"report_achievement", [achievement], done)
