# Platform achievements: how to finish the adapters

Read this to finish #25 on a platform. ADR-0019 has the design. The code is in `src/platform/achievements/`, and the achievements are in `data/achievements.json`.

## What is done

- The core records milestones and sends `Simulation.milestone_reached` (`src/core/milestones.gd`).
- `data/achievements.json` maps 12 sample achievements to milestones. The names, the descriptions, and the ids are placeholders.
- `AchievementTracker` unlocks achievements through one `AchievementService`. It unlocks all that the milestones grant at each start, after each import and cloud load, and when the service becomes available. It does not unlock what only an imported export code gave (ADR-0019, "An imported code grants nothing that only the import gave").
- `TestAchievementService` lets the game run with no platform service. `AchievementServices.for_this_device()` picks it when the device has no SDK or plugin, or when Steam does not start.
- The Steam, Game Center, and Google Play Games adapters are written. Each one gets its SDK or plugin as an object, so the unit tests (`tests/unit/test_achievement_adapters.gd`) give it a fake. Each method name, signal name, and property name was checked against the plugin source (versions below). **No one ran them with a real SDK or on a device yet.**
- `src/platform/platform_sdks.gd` (`PlatformSdks`) starts GodotSteam and initializes the Play Games plugin once in the process. The achievements use it. The cloud save adapters (#24) do not use it yet: `GooglePlayCloudSave` calls `initialize()` itself, so Play Games is initialized twice until #24 changes it.

## Plugins and versions

| Platform | Plugin | Checked against | How the game finds it |
| --- | --- | --- | --- |
| Steam | GodotSteam GDExtension (https://codeberg.org/godotsteam/godotsteam) | 4.24 (tag `v4.24-gde`, Steamworks SDK 1.65) | Engine singleton `Steam`, started by `PlatformSdks.steam()` |
| Game Center | GodotApplePlugins, its Game Center addon (https://github.com/migueldeicaza/GodotApplePlugins) | commit `a66f619` (2026-10-21, Asset Library 4552 version 1.11) | ClassDB classes `GameCenterManager` and `GKAchievement`, through `GameKit.for_this_build()` |
| Google Play Games | godot-play-game-services (https://github.com/godot-sdk-integrations/godot-play-game-services) | 3.4.0 (2026-07-20) | Android singleton `GodotPlayGameServices`, initialized by `PlatformSdks.play_games()` |

The cloud save (#24) uses the same three plugins. For Game Center, the earlier skeleton followed the `GameCenter` plugin of `godotengine/godot-ios-plugins`. That plugin has no Godot 4 release, so this branch uses GodotApplePlugins, the plugin of the iCloud save. This is a recommendation: the user can choose another plugin. GodotApplePlugins needs iOS 17 or later.

Not confirmed from the sources:

- The value 0 for a good `steamInitEx()` status. It is `k_ESteamAPIInitResult_OK` of the Steamworks SDK, which is not in the GodotSteam repository.
- What a second `PlayGamesSdk.initialize()` does. `PlatformSdks` calls it once, but `GooglePlayCloudSave` (#24) still calls `initialize()` itself until it uses `PlatformSdks.play_games()`.
- What Google Play does with an unlock that fails with no network. The plugin uses `unlockImmediate`, which does not queue. The adapter logs the failure, and the tracker sends it again at the next start.
- The thread of the answers of the Play Games plugin and of Game Center. The adapters take them deferred, so either thread works.
- GodotApplePlugins on Godot 4.7. It says Godot 4.2 or later.

## Steps for each platform

Each platform needs the same five steps:

1. Get the developer account and a test device or test account.
2. Add the SDK or plugin to the build. Do not add SDK binaries to this repository until the user decides how the build gets them (see #28). Add each of its files, permissions, and capabilities to the allowlists of the build checks (`tests/helpers/store_policy.gd`) in the same change.
3. Make each achievement in the platform's dashboard, and put its id in `platform_ids` in `data/achievements.json`.
4. If the plugin version is not the one in the table above, check the names in the adapter again, and update the table.
5. Do the smoke test: start a new game, make the first sale, and see "First sale" unlock on the platform. Then close the game, reset the achievement in the dashboard, and start the game again: the tracker must unlock it again from the save. Then import an export code of another game that has the first sale, reset the achievement again, and start the game again: it must not unlock.

### Steam (`steam_achievement_service.gd`)

- Add GodotSteam 4.24 or later as a GDExtension. Set the app id in its project setting `steam/initialization/app_data/app_id`, or put `steam_appid.txt` beside the game for runs outside Steam.
- `PlatformSdks.steam()` starts Steam with `steamInitEx(0, true)`, which also turns on embedded callbacks. If GodotSteam started itself (its setting `steam/initialization/processes/initialize_on_startup`), `get_steam_init_result()` tells this, and it does not start Steam again. Then also turn on `steam/initialization/processes/embed_callbacks`, or the Steam adapter runs the callbacks in `poll()`.
- Dashboard: Steamworks, App Admin, Stats and Achievements. The "API Name" is the `steam` id. The sample data uses the achievement id in capitals, such as `FIRST_SALE`. Publish the changes in Steamworks.
- The adapter calls `setAchievement(name)` (false when Steamworks has no such achievement) and then `storeStats()`. Since Steamworks SDK 1.61, Steam loads the stats at start, so no request is needed first.
- Steam keeps an unlock on the device while it is offline, and sends it later.
- If Steam does not start (no Steam client), the game uses the test adapter.

### Game Center (`game_center_achievement_service.gd` and `game_kit.gd`)

- Add the Game Center addon of GodotApplePlugins (`addons/GodotApplePluginsGameCenter`), or the addon with all its modules. The Foundation addon alone, which the iCloud save needs, has no Game Center.
- Turn on Game Center for the App ID at developer.apple.com, and add the entitlement `com.apple.developer.game-center` to the iOS export (#28 owns the export presets). Without it, the calls do nothing.
- Dashboard: App Store Connect, the app, Game Center, Achievements. The "Achievement ID" is the `game_center` id. The sample data uses `incrementalrainbow.<id>`.
- `GameKit` calls `GameCenterManager.authenticate()` and listens to `authentication_result(status)` and `authentication_error(message)`. iOS can show its sign-in view. To unlock, it makes `GKAchievement.make(id)`, sets `percent_complete` to 100 and `shows_completion_banner` to true, and calls `GKAchievement.report_achievement([achievement], callback)`. (The plugin guide writes `show_completion_banner`, which is wrong.)
- A report can fail with no network. The adapter logs it, and the tracker sends it again at the next start of the game.

### Google Play Games (`google_play_achievement_service.gd`)

- Add godot-play-game-services 3.4.0 or later. It needs the Gradle build for Android.
- Put the game's Play Games project id in the Android export option `godot_play_game_services/game_id` (#28 owns the export presets).
- Dashboard: Play Console, Play Games Services, Achievements. The Play Console gives each achievement its id (such as `CgkI...`). Put each one in `google_play`. The sample data has none yet, so this platform unlocks nothing until then.
- Add the test accounts in the Play Console.
- The adapter calls `isAuthenticated()` at start, listens to `userAuthenticated(bool)`, calls `unlockAchievement(id)`, and logs a failed `achievementUnlocked(false, id)`.
- The plugin does not sign in by itself. If Play Games does not sign the player in at start, the game must give the player a way to sign in with `signIn()`. No such button exists yet.

## Acceptance criteria that are still open

- A smoke test on each platform unlocks one achievement (step 5 above, on Steam, iOS, and Android).
