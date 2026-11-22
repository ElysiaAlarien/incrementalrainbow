class_name GameCenterAchievementService
extends AchievementService
## The Game Center adapter, for an iOS plugin with a [code]GameCenter[/code]
## engine singleton. SKELETON: no one has run it on an iOS device yet.
## docs/achievements.md says what a person must do to finish it.
##
## It names no plugin class or method in the code, so that the script parses
## in a build with no plugin. It finds the singleton at run time and calls its
## methods by name. With no singleton, or with a method that is not there, it
## does nothing.
##
## NOT VERIFIED: the method names and event shapes below are from the
## GameCenter plugin of godotengine/godot-ios-plugins, not from a test. Which
## iOS plugin the game uses is a decision for the user. Check the names
## against that plugin.

const SINGLETON := &"GameCenter"

var _game_center: Object = null
var _authenticated := false


func _init() -> void:
	if Engine.has_singleton(SINGLETON):
		_game_center = Engine.get_singleton(SINGLETON)
		if _game_center.has_method(&"authenticate"):
			# The result comes later as a pending event (see [method poll]).
			_game_center.call(&"authenticate")


func platform() -> StringName:
	return &"game_center"


func has_sdk() -> bool:
	return _game_center != null


func is_available() -> bool:
	return _authenticated


func unlock(def: AchievementDef) -> bool:
	var achievement_id := def.platform_id(platform())
	if not _authenticated or achievement_id.is_empty() or not _game_center.has_method(&"award_achievement"):
		return false
	_game_center.call(&"award_achievement", {
		"name": achievement_id,
		"progress": 100.0,
		"show_completion_banner": true,
	})
	return true


## Reads the events of the plugin. An authentication event with the result
## "ok" makes the service available.
func poll() -> void:
	if _game_center == null or not _game_center.has_method(&"get_pending_event_count") \
			or not _game_center.has_method(&"pop_pending_event"):
		return
	while int(_game_center.call(&"get_pending_event_count")) > 0:
		var event: Variant = _game_center.call(&"pop_pending_event")
		if event is Dictionary and event.get("type") == "authentication" and event.get("result") == "ok" \
				and not _authenticated:
			_authenticated = true
			became_available.emit()
