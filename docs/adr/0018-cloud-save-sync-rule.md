# Cloud save: one interface, a three-way sync, and the later save wins a conflict

_Status: proposed (#24). The conflict rule is a decision for the user. See "Decisions for the user"._

The save syncs with the platform cloud save: Steam Cloud, iCloud, or Google Play. Each platform is an adapter of one interface, `CloudSave` (in `src/platform/cloud_save/`), outside the core. An adapter only reads and writes one text. It does not decide anything. `CloudSaveSession` and `CloudSync` decide, so each platform follows the same rule.

## The cloud keeps the export code

The cloud save is the export code of the save (ADR-0010), not the save JSON. It is the same save, so the load uses the same migrations and the same strict checks. Deflate makes it much smaller (the iCloud key-value store keeps at most 1 MB for each value). The checksum finds a cloud save that is cut off. A code of a newer game fails with the reason `NEWER_VERSION`.

## A sync is three-way

A sync compares three saves: the game on the device, the cloud save, and the cloud save after the last good sync on this device (the sync base). The game keeps the SHA-256 of the sync base in a small file beside the save (`save.json.cloud`). The sync base is not in the save, because it is true only for one device. Thus the core state does not change, and this needs no migration.

| Device since the sync base | Cloud since the sync base | Result |
| --- | --- | --- |
| no change | no change | nothing |
| changed | no change, or no cloud save | upload the device |
| no change | changed | use the cloud save, and tell the player |
| changed | changed | conflict: the rule below picks one |

A device with no sync base (the first sync, or an update that adds the cloud save) has a conflict when the two saves are different. A game that started new on this device and never synced (a new install, or a save that could not load) loses to a cloud save, so that a new install cannot replace a long game. Without this, the new game would win, because it saved last.

## The conflict rule: the save that saved last wins

In a conflict, the save with the later save time (ADR-0009) wins. On the same time, the device wins, because no change is the safe default. A save with no save time (version 12 or older) loses to a save with one. The game tells the player which save it uses, and why, in a dialog.

We chose this rule because the player can understand it ("the game you played last"), and it needs no new value in the save. The weak point is the device clock: a device with a clock that is wrong by hours can win when it should lose. Phones and computers set their clocks from the network, so we accept this risk. The kept save (below) lets the player undo a wrong choice.

Other rules that we considered:

- **The longer play time wins.** This is a better measure of progress, and a wrong clock does not change it. But the save has no total play time, because the run time starts again at each prestige (ADR-0012). It needs a new value in the core state and a save migration.
- **More progress wins** (for example more prisms bought, then more money). This is hard to define for an incremental game, because the player spends money and prestige clears the run.
- **The player always picks.** This is the safest, but it asks a question at each conflict, also when one answer is clear.
- **The platform picks** (Steam Auto-Cloud, or a Google Play resolution policy). Each platform then has a different rule, and Steam Auto-Cloud shows its own dialog outside the game. We rejected this, because the issue asks for one clear rule.

## Nothing is lost

A sync never destroys a save. Before the game replaces the save on the device, or uploads over a different cloud save, it keeps the other one in `save.json.other`. The conflict dialog has a button that changes to the other game (it keeps the replaced game in its place). A cloud save that cannot load is kept the same way, then replaced. A cloud save of a newer game is never replaced: the game tells the player to update, and does not sync again until it starts again.

## When the game syncs

- When the game starts, after it loads the save on the device. The game plays at once and does not wait for the cloud. When the cloud save wins, it replaces the game, as an import does.
- Every 5 minutes, and when a phone game comes back from the background.
- When the game goes to the background or quits. These syncs only upload. A change of game or a conflict waits for the next sync, because the player cannot see it then.

A sync waits at most 20 seconds for each answer of a service. Only one sync runs at a time. There is no compare-and-swap on any platform, so two devices that upload at the same second can lose one upload. The next sync of that device then finds a conflict, and the kept save has the other game.

## Adapters with no SDK

An adapter names no SDK class in its script. It finds the SDK with `Engine.has_singleton` or `ClassDB.class_exists`, and calls it with `call`. Thus the game loads and runs when the SDK or plugin is not in the build: the adapter is "not available", and the game saves only on the device. CI tests this for each adapter. `TestCloudSave` keeps the save in memory or in a folder, so that tests and a person on one computer can test the rule with no platform service.

## Decisions for the user

1. **The conflict rule.** Proposed: the save that saved last wins, and the player can change to the other. Alternatives are above. Not decided.
2. **Steam: the Remote Storage API or Auto-Cloud.** Proposed: the API (GodotSteam), so that Steam follows the same rule. Auto-Cloud needs no code, but Steam then shows its own conflict dialog. Not decided.
3. **iCloud plugin.** Proposed: GodotApplePlugins (its `NSUbiquitousKeyValueStore` class), which is maintained. The older `godot-ios-plugins` iCloud plugin has no Godot 4 release. Not decided.
