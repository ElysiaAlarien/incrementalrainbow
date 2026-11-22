class_name GooglePlayAchievementService
extends AchievementService
## The Google Play Games adapter, for an Android plugin with an engine
## singleton. SKELETON: no one has run it on an Android device yet.
## docs/achievements.md says what a person must do to finish it.
##
## It names no plugin class or method in the code, so that the script parses
## in a build with no plugin. It finds the singleton at run time and calls its
## methods by name. With no singleton, or with a method that is not there, it
## does nothing.
##
## NOT VERIFIED: the singleton name, the method names, and the signal below
## are from the documentation of the Godot Play Game Services plugin
## (godot-sdk-integrations/godot-play-game-services), not from a test. Which
## Android plugin the game uses is a decision for the user. Check the names
## against that plugin.

const SINGLETON := &"GodotAndroidPlayGameServices"
## The signal of the plugin with the sign-in result, a bool.
const AUTHENTICATED_SIGNAL := &"userAuthenticated"

var _play_games: Object = null
var _authenticated := false


func _init() -> void:
	if not Engine.has_singleton(SINGLETON):
		return
	_play_games = Engine.get_singleton(SINGLETON)
	if _play_games.has_signal(AUTHENTICATED_SIGNAL):
		_play_games.connect(AUTHENTICATED_SIGNAL, _on_authenticated)
	if _play_games.has_method(&"initialize"):
		_play_games.call(&"initialize")
	if _play_games.has_method(&"isAuthenticated"):
		# The result comes later through the signal.
		_play_games.call(&"isAuthenticated")


func platform() -> StringName:
	return &"google_play"


func has_sdk() -> bool:
	return _play_games != null


func is_available() -> bool:
	return _authenticated


func unlock(def: AchievementDef) -> bool:
	var achievement_id := def.platform_id(platform())
	if not _authenticated or achievement_id.is_empty() or not _play_games.has_method(&"unlockAchievement"):
		return false
	_play_games.call(&"unlockAchievement", achievement_id)
	return true


func _on_authenticated(is_authenticated: bool) -> void:
	if is_authenticated and not _authenticated:
		_authenticated = true
		became_available.emit()
