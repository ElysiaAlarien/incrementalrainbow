class_name PlatformSdks
extends RefCounted
## Starts each platform SDK once in the process, for each of its users: the
## achievements (#25) and the cloud save (#24). An SDK that two users start
## twice can fail or log errors, so each user gets the SDK from here.
##
## It names no SDK class, so it loads in a build with no SDK, and then each
## function returns null. The names come from the plugin sources that
## docs/achievements.md lists.

## The engine singleton of GodotSteam.
const STEAM := &"Steam"
## The Android singleton of godot-play-game-services.
const PLAY_GAMES := &"GodotPlayGameServices"
## The status of a good [code]steamInitEx()[/code]: STEAM_API_INIT_RESULT_OK,
## which is k_ESteamAPIInitResult_OK (0) of the Steamworks SDK.
const STEAM_INIT_OK := 0

static var _steam: Object = null
static var _steam_tried := false
static var _play_games: Object = null
static var _play_games_tried := false


## The GodotSteam singleton after a good start, or null when the build has no
## GodotSteam or Steam did not start (for example, the Steam client is not
## running). It tries to start Steam once only.
static func steam() -> Object:
	if not _steam_tried:
		_steam_tried = true
		if Engine.has_singleton(STEAM):
			var sdk := Engine.get_singleton(STEAM)
			if start_steam(sdk):
				_steam = sdk
	return _steam


## The Play Games plugin singleton after [code]initialize()[/code], or null
## when the build has no plugin. It initializes the plugin once only. The
## player is not signed in yet: each user asks with
## [code]isAuthenticated()[/code] and listens to [code]userAuthenticated[/code].
static func play_games() -> Object:
	if not _play_games_tried:
		_play_games_tried = true
		if Engine.has_singleton(PLAY_GAMES):
			_play_games = Engine.get_singleton(PLAY_GAMES)
			_play_games.call(&"initialize")
	return _play_games


## Starts Steam on [param sdk], a GodotSteam singleton. Returns true when
## Steam started. The app id comes from the GodotSteam project settings (0
## here). GodotSteam runs the callbacks each frame (embedded callbacks), so no
## user must call [code]run_callbacks()[/code], and a call to it does
## nothing. Use [method steam]: this is public for the tests.
##
## Leave the GodotSteam setting
## [code]steam/initialization/processes/initialize_on_startup[/code] off.
## With it on, this second start logs "Steam is already initialized." and gives
## the result of the first.
static func start_steam(sdk: Object) -> bool:
	var result: Variant = sdk.call(&"steamInitEx", 0, true)
	if result is Dictionary and result.get("status") == STEAM_INIT_OK:
		return true
	var verbal: String = result.get("verbal", "") if result is Dictionary else ""
	print_verbose("Steam did not start: %s" % verbal)
	return false
