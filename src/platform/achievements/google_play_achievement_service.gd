class_name GooglePlayAchievementService
extends AchievementService
## The Google Play Games adapter, for the Android plugin
## godot-play-game-services. The names are checked against the source of the
## plugin, version 3.4.0, but no one ran it on a device yet.
## docs/achievements.md says what a person must do to finish it.
##
## It names no plugin class, so the script parses in a build with no plugin.
## It calls the methods of the plugin singleton by name, not the GDScript nodes
## of the plugin's addon. [method AchievementServices.for_this_device] gives it
## the singleton from [method PlatformSdks.play_games], which initializes the
## plugin once for the achievements and the cloud save.
##
## The plugin answers with signals, which can come from another thread, so the
## adapter takes them deferred.

## The plugin's signal with the sign-in result, a bool.
const AUTHENTICATED_SIGNAL := &"userAuthenticated"
## The plugin's signal with the result of an unlock: (is_unlocked, id).
const UNLOCKED_SIGNAL := &"achievementUnlocked"

## The Play Console ids of the unlocks that Google Play answered as failed in
## this session. The tracker sends them again at the next start.
var failed_unlocks: Array[String] = []

var _play_games: Object
var _authenticated := false


## [param play_games] is the plugin singleton after
## [code]initialize()[/code], or null for a build with no plugin.
func _init(play_games: Object = null) -> void:
	_play_games = play_games
	if _play_games == null:
		return
	_play_games.connect(AUTHENTICATED_SIGNAL, _on_authenticated, CONNECT_DEFERRED)
	_play_games.connect(UNLOCKED_SIGNAL, _on_unlocked, CONNECT_DEFERRED)
	# The plugin does not check the sign-in itself. The result comes through
	# the signal.
	_play_games.call(&"isAuthenticated")


func platform() -> StringName:
	return &"google_play"


func has_sdk() -> bool:
	return _play_games != null


func is_available() -> bool:
	return _authenticated


## Returns true when the unlock went to the plugin. The plugin sends it at
## once and does not keep it with no network: [signal achievementUnlocked]
## says when it failed.
func unlock(def: AchievementDef) -> bool:
	var achievement_id := def.platform_id(platform())
	if not _authenticated or achievement_id.is_empty():
		return false
	_play_games.call(&"unlockAchievement", achievement_id)
	return true


func _on_authenticated(is_authenticated: bool) -> void:
	var became := is_authenticated and not _authenticated
	_authenticated = is_authenticated
	if became:
		became_available.emit()


func _on_unlocked(is_unlocked: bool, achievement_id: String) -> void:
	if not is_unlocked:
		failed_unlocks.append(achievement_id)
		push_warning("Google Play Games did not unlock %s. The game tries again at the next start." % achievement_id)
