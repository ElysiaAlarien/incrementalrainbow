class_name GameCenterAchievementService
extends AchievementService
## The Game Center adapter, through [GameKit] (the GodotApplePlugins
## GDExtension, which the iCloud save also uses). The names are checked against
## the plugin source, but no one ran it on an iOS device yet.
## docs/achievements.md says what a person must do to finish it.

## The Game Center ids of the reports that Game Center answered as failed in
## this session, for the tests. The tracker does not read it: it sends each
## earned achievement again at the next start.
var failed_unlocks: Array[String] = []

var _kit: GameKit
var _authenticated := false


## [param kit] is the [GameKit] of the build, or null for a build with no Game
## Center. It starts the sign-in.
func _init(kit: GameKit = null) -> void:
	_kit = kit
	if _kit == null:
		return
	_kit.authentication_result.connect(_on_authentication_result, CONNECT_DEFERRED)
	_kit.authentication_error.connect(_on_authentication_error, CONNECT_DEFERRED)
	_kit.authenticate()


func platform() -> StringName:
	return &"game_center"


func has_sdk() -> bool:
	return _kit != null


func is_available() -> bool:
	return _authenticated


## Returns true when the report went to Game Center. The answer comes later.
func unlock(def: AchievementDef) -> bool:
	var achievement_id := def.platform_id(platform())
	if not _authenticated or achievement_id.is_empty():
		return false
	# A bound method, not a lambda: the plugin can keep the callback, and a
	# lambda would keep this service with it.
	_kit.report(achievement_id, _on_answer.bind(achievement_id))
	return true


func _on_authentication_result(status: bool) -> void:
	var signed_in_now := status and not _authenticated
	_authenticated = status
	if signed_in_now:
		became_available.emit()


func _on_authentication_error(message: String) -> void:
	push_warning("Game Center sign-in failed: %s" % message)


## The answer of Game Center, which can come from another thread.
func _on_answer(error: Variant, achievement_id: String) -> void:
	_on_reported.call_deferred(achievement_id, error)


func _on_reported(achievement_id: String, error: Variant) -> void:
	if error != null:
		failed_unlocks.append(achievement_id)
		push_warning("Game Center did not take %s (%s). The game tries again at the next start." % [
			achievement_id, error])
