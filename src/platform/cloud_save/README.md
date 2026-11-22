# Cloud save adapters

ADR-0018 has the design. `CloudSave` is the one interface, and `CloudSaveSession` and `CloudSync` hold the rule. `CloudSaves.for_device()` picks the adapter.

| Adapter | Plugin | Status |
| --- | --- | --- |
| `CloudSave` (no cloud) | none | Done. |
| `TestCloudSave` | none | Done, with tests. |
| `SteamCloudSave` | GodotSteam v4.24 | Done, with tests against a fake. Not tested on Steam. |
| `ICloudSave` | GodotApplePlugins, commit `a66f619` | Done, with tests against a fake. Not tested on a device. One open risk (below). |
| `GooglePlayCloudSave` | godot-play-game-services v3.4.0 | Done, with tests against a fake. Not tested on a device. |

Each adapter takes its SDK object in `_init`. The game gives none, so the adapter finds the singleton or class itself. The tests give a fake with the method and signal names of the plugin version above (`tests/unit/cloud_save/test_*_cloud_save.gd`, `test_icloud_save.gd`). The names come from the plugin sources in November 2026. If you install a different version, check the names again.

With no SDK or plugin in the build, each adapter loads and is not available, so the game saves only on the device. CI tests this (`tests/unit/cloud_save/test_cloud_save_adapters.gd`).

When you add a plugin, also add each of its files, permissions, and capabilities to the allowlists of the build checks (#28, `tests/helpers/store_policy.gd`), in the same change.

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
3. Add GodotSteam v4.24 as a GDExtension (https://codeberg.org/godotsteam/godotsteam). Do not commit the Steam SDK binaries if the license does not allow it; see #28 for the build.
4. Start Steam once. `SteamCloudSave` never starts Steam: it uses Steam only when `get_steam_init_result()` has the status 0. The simplest start is in the project settings of GodotSteam: turn on `steam/initialization/processes/initialize_on_startup` and `steam/initialization/processes/embed_callbacks`, and set the app ID. Then GodotSteam starts Steam itself and runs its callbacks each frame. The achievements of #25 call `steamInitEx` today. A second start logs "Steam is already initialized.", so keep only one.
5. Smoke test on two computers with one Steam account: save, sync, load, and a conflict. Also with Steam Cloud off in the Steam client, and with the Steam client closed.

Note: `fileWrite` writes the copy of Steam on the computer. The Steam client uploads it later, also after the game quits.

## iCloud: what a person must do

1. Get an Apple Developer account, and turn on iCloud with the key-value store for the app ID.
2. Add the entitlement `com.apple.developer.ubiquity-kvstore-identifier` to the iOS export (#28 owns the export presets). Without it, `synchronize()` is false, and each sync fails with a message.
3. Add GodotApplePlugins (https://github.com/migueldeicaza/GodotApplePlugins, Asset Library 4552, commit `a66f619` or later). `ICloudSave` uses its class `NSUbiquitousKeyValueStore`: `default_store()`, `synchronize()`, `string_for_key(key)`, and `set_string(value, key)`. It keeps one wrapper, because `default_store()` makes a new one at each call.
4. Smoke test on two devices with one Apple ID: save, sync, load, and a conflict. Also with iCloud off for the app, and with no Apple account on the device.
5. Smoke test the open risk: sign in to an Apple account on a device that has never had the game, install the game, and start it at once. Check that it loads the cloud game, and does not upload a new game over it.

Notes:

- The key-value store works with no Apple account, but then it keeps the save only on the device. The game cannot tell this case from a sync with no change.
- **Open risk: the first download.** Apple says that the system downloads the store from iCloud when a person signs in to an Apple account on the device (the documentation of `NSUbiquitousKeyValueStoreInitialSyncChange`). Until that download ends, the store can be empty, and Apple says to wait before a write. In that time, a new install reads no cloud save, and uploads its new game. Apple does not say what happens to that write. If iCloud keeps it, the new game replaces the cloud game in iCloud. The cloud game is then only on the other devices, and their next sync finds a conflict. Step 5 checks this. A fix is to wait for the plugin signal `did_change_externally` with the reason `INITIAL_SYNC_CHANGE` (1) before the first upload, but no one can check when that signal comes without a device.
- Optional: connect `did_change_externally` to a sync, so that a change from another device comes while the game runs. Today the game syncs at start, on return from the background, and every 5 minutes.

## Google Play: what a person must do

1. Get a Google Play Console account, make the game in Play Games Services, and turn on Saved Games.
2. Add the godot-play-game-services plugin v3.4.0 (https://github.com/godot-sdk-integrations/godot-play-game-services), with its game ID in the Android export (#28).
3. `GooglePlayCloudSave` calls the Android singleton `GodotPlayGameServices` directly, not the GDScript nodes of the addon: `initialize()`, `isAuthenticated()` with the signal `userAuthenticated(bool)`, `loadGame(name, false)` with `gameLoaded(json)`, `saveGame(name, description, bytes, 0, 0)` with `gameSaved(bool, name, description)`, and `conflictEmitted(json)`.
4. The adapter calls `initialize()` when the game starts. The achievements of #25 and the addon autoload can call it too. Check on a device that a second call does no harm, or give it one owner.
5. Smoke test on two devices with one Google account: save, sync, load, and a conflict. Also when the player is not signed in, with no network, and with the network off during a save.

How the adapter uses the plugin, from its source:

- The sign-in answer comes later by signal. A read or a write before it waits for it, so the sync at the start works. When the player is not signed in, the adapter is not available, and a sync does nothing. A sign-in after the start syncs at the next sync (in 5 minutes or on return from the background).
- `gameLoaded` has the snapshot as JSON. Gson writes its content as an array of numbers from -128 to 127. "null" means that there is no snapshot.
- The plugin sends no signal for most errors of a read or a write. Then the operation fails at the timeout (20 seconds), and the next sync tries again.
- Each write has its own description ("Incremental Rainbow, saved <date and time>"), and `gameSaved` sends it back. So a late answer to an earlier write does not finish the next write.

Limits of the plugin (ADR-0018 has them too):

- The plugin opens each snapshot with a resolution policy of Google: "highest progress" for a write and "most recently modified" for a read. So Google resolves a conflict between two devices itself, before the game sees it, and the cloud does not keep the version that loses. The device that wrote it still has its game. At its next sync, the cloud is different from its sync base, so the rule of ADR-0018 picks one game, keeps the other in the kept save, and tells the player.
- `gameSaved(true)` comes before the write is committed, and the plugin does not report a commit that fails. Then the game records a sync that did not happen. At the next sync, the cloud is different from the sync base. If the device did not change, the older cloud game loads, the game on the device goes to the kept save, and the player is told.
