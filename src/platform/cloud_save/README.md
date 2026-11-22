# Cloud save adapters

ADR-0018 has the design. `CloudSave` is the one interface, and `CloudSaveSession` and `CloudSync` hold the rule. `CloudSaves.for_device()` picks the adapter.

| Adapter | Status |
| --- | --- |
| `CloudSave` (no cloud) | Done. |
| `TestCloudSave` | Done, with tests. |
| `SteamCloudSave` | Skeleton. Not tested on Steam. |
| `ICloudSave` | Skeleton. Not tested on a device. |
| `GooglePlayCloudSave` | Skeleton. Not tested on a device. |

Each skeleton loads and runs with no SDK or plugin, and CI tests this (`tests/unit/cloud_save/test_cloud_save_adapters.gd`). The SDK method names come from the plugin sources in November 2026 (links below). Check them against the plugin version that you install.

## Test the rule on one computer

Start two copies of the game, each with its own save, and one folder as the cloud:

```bash
godot --path . -- --test-cloud-save=/tmp/ir-cloud --save-path=user://device_a.json
```

```bash
godot --path . -- --test-cloud-save=/tmp/ir-cloud --save-path=user://device_b.json
```

Play on A and quit. Start B: it loads the game of A. Play on both, then quit A, and then quit B. Start B again to see the conflict dialog.

## Steam Cloud: what a person must do

1. Get a Steamworks partner account and an app ID.
2. On the Steamworks partner site, open Steam Cloud for the app, and set a byte quota (1 MB is enough) and a file count of at least 1. Do NOT set Auto-Cloud paths for the save, or Steam syncs the save file a second time with its own rule. (ADR-0018 lists API or Auto-Cloud as a decision for the user.)
3. Add GodotSteam as a GDExtension (https://codeberg.org/godotsteam/godotsteam, v4.24 or later). Do not commit the Steam SDK binaries if the license does not allow it; see #28 for the build.
4. Initialize Steam once when the game starts (`Steam.steamInitEx()`), and run its callbacks each frame or turn on embedded callbacks. #25 (achievements) needs the same. Put it in one place and do not initialize twice.
5. Check `SteamCloudSave` against the installed version: `isCloudEnabledForAccount`, `isCloudEnabledForApp`, `fileExists`, `getFileSize`, `fileRead` (a Dictionary with `ret` and `buf`), and `fileWrite`.
6. Smoke test on two computers with one Steam account: save, sync, load, and a conflict. Also with Steam Cloud off in the Steam client.

## iCloud: what a person must do

1. Get an Apple Developer account, and turn on iCloud with the key-value store for the app ID.
2. Add the entitlement `com.apple.developer.ubiquity-kvstore-identifier` to the iOS export (#28 owns the export presets).
3. Add GodotApplePlugins (https://github.com/migueldeicaza/GodotApplePlugins, Asset Library 4552). `ICloudSave` uses its class `NSUbiquitousKeyValueStore`: `default_store()`, `synchronize()`, `string_for_key(key)`, and `set_string(value, key)`.
4. Optional: connect the signal `did_change_externally` to a sync, so that a change from another device comes while the game runs. Today the game syncs at start, on return from the background, and every 5 minutes.
5. Note: the key-value store works with no iCloud account, but then it does not sync. The game cannot tell this case from a sync with no change.
6. Smoke test on two devices with one Apple ID: save, sync, load, and a conflict. Also with iCloud off for the app.

## Google Play: what a person must do

1. Get a Google Play Console account, make the game in Play Games Services, and turn on Saved Games.
2. Add the godot-play-game-services plugin (https://github.com/godot-sdk-integrations/godot-play-game-services, v3.4.0 or later), with its game ID in the Android export (#28).
3. `GooglePlayCloudSave` calls the Android singleton `GodotPlayGameServices` directly, not the GDScript nodes of the addon: `initialize()`, `isAuthenticated()` with the signal `userAuthenticated(bool)`, `loadGame(name, create_if_not_found)` with `gameLoaded(json)`, `saveGame(name, description, bytes, played_time, progress)` with `gameSaved(bool, name, description)`, and `conflictEmitted(json)`.
4. NOT VERIFIED: how the plugin puts the snapshot bytes in the JSON of `gameLoaded` (`_bytes()` accepts an array of numbers or base64), and whether the plugin resolves a conflict itself. Check both on a device.
5. #25 (achievements) also uses this plugin. Call `initialize()` once only.
6. The player must sign in to Play Games. Until then, the adapter is not available, and a sync does nothing. A sign-in after the start syncs at the next sync (in 5 minutes or on return from the background).
7. Smoke test on two devices with one Google account: save, sync, load, and a conflict. Also when the player is not signed in.
