# Platform achievements: how to finish the adapters

Read this to finish #25 on a platform. ADR-0018 has the design. The code is in `src/platform/achievements/`, and the achievements are in `data/achievements.json`.

## What is done

- The core records milestones and sends `Simulation.milestone_reached` (`src/core/milestones.gd`).
- `data/achievements.json` maps 12 sample achievements to milestones. The names, the descriptions, and the ids are placeholders.
- `AchievementTracker` unlocks achievements through one `AchievementService`. It unlocks all that the milestones grant at each start, after each import, and when the service becomes available.
- `TestAchievementService` lets the game run with no platform service. `AchievementServices.for_this_device()` picks it when the device has no SDK or plugin.
- The Steam, Game Center, and Google Play Games adapters are skeletons. They find the SDK or plugin at run time and do nothing when it is not there. The method names in them are **not verified**.

## Steps for each platform

Each platform needs the same five steps:

1. Get the developer account and a test device or test account.
2. Add the SDK or plugin to the build. Do not add SDK binaries to this repository until the user decides how the build gets them (see #28).
3. Make each achievement in the platform's dashboard, and put its id in `platform_ids` in `data/achievements.json`.
4. Check each method name, signal name, and result shape in the adapter against the version of the SDK or plugin. Fix the adapter where they differ, and remove its "NOT VERIFIED" notes.
5. Do the smoke test: start a new game, make the first sale, and see "First sale" unlock on the platform. Then close the game, reset the achievement in the dashboard, and start the game again: the tracker must unlock it again from the save.

### Steam (`steam_achievement_service.gd`)

- SDK: the GodotSteam extension for Godot 4.7, with `steam_appid.txt` (or the app id in the GodotSteam settings) for runs outside Steam.
- Dashboard: Steamworks, App Admin, Stats and Achievements. The "API Name" is the `steam` id. The sample data uses the achievement id in capitals, such as `FIRST_SALE`. Publish the changes in Steamworks.
- Check: `steamInitEx()` and its result, `setAchievement(name)`, `storeStats()`, and `run_callbacks()`. If the build has GodotSteam embed its callbacks, `poll()` can do nothing.
- Steam keeps an unlock on the device while it is offline, and sends it later.

### Game Center (`game_center_achievement_service.gd`)

- Plugin: an iOS plugin with a `GameCenter` singleton. The adapter follows the GameCenter plugin of `godotengine/godot-ios-plugins`. Other plugins have other names. Which plugin to use is a decision for the user.
- Turn on the Game Center capability for the app in Xcode and in App Store Connect.
- Dashboard: App Store Connect, the app, Game Center, Achievements. The "Achievement ID" is the `game_center` id. The sample data uses `incrementalrainbow.<id>`.
- Check: `authenticate()`, the pending events (`get_pending_event_count()` and `pop_pending_event()`, an authentication event with `"result": "ok"`), and `award_achievement({"name", "progress", "show_completion_banner"})`.
- An award can fail with no network. The tracker sends it again at the next start of the game.

### Google Play Games (`google_play_achievement_service.gd`)

- Plugin: an Android plugin for Play Games Services v2. The adapter follows the Godot Play Game Services plugin (`godot-sdk-integrations/godot-play-game-services`), with the singleton `GodotAndroidPlayGameServices`. Which plugin to use is a decision for the user.
- Dashboard: Play Console, Play Games Services, Achievements. The Play Console gives each achievement its id (such as `CgkI...`). Put each one in `google_play`. The sample data has none yet, so this platform unlocks nothing until then.
- Put the game's Play Games project id in the plugin's settings, and add the test accounts in the Play Console.
- Check: the singleton name, `initialize()`, `isAuthenticated()`, the signal `userAuthenticated(bool)`, and `unlockAchievement(id)`.

## Acceptance criteria that are still open

- A smoke test on each platform unlocks one achievement (step 5 above, on Steam, iOS, and Android).
