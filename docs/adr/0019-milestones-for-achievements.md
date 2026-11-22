# The core records milestones, and platform achievements react to them

Platform achievements (#25) for Steam, Game Center, and Google Play Games must react to core events (spec #1). They sit outside the core, behind one interface.

**The core records milestones in the save.** A milestone is a lifetime record of something the player did: the first time they did it (value 1), or the highest count they reached. A milestone only goes up. `Simulation._milestones` holds them, `milestones()` reads them, and the snapshot key is `milestones` (a list of `{"id", "value", "imported"}`, sorted by id; see "An imported code grants nothing" for `imported`). A prestige keeps them (`_PRESTIGE_KEEPS`, ADR-0012). `src/core/milestones.gd` has the ids. Some ids have one id for each item of the content, such as `factory.brown` or `research.earth_tones`.

We record them, not only send events, for three reasons:

- The player gets the achievements of a save that moves to another device of the player by a cloud save (ADR-0018). The other platform never saw the events.
- A platform that is not available (no sign-in, no network) gets the unlocks later. The tracker unlocks all that the milestones grant at each start, and when the service becomes available.
- Counts such as the prestiges are not in the rest of the state.

**The core sends an event when a milestone goes up.** `Simulation.milestone_reached(id, value)` is a signal, so it adds one kind of call to ADR-0008. Commands and tick events raise milestones where the change happens: a sale, a completed research, a prestige. No rule samples the state at the end of a tick, so one long tick and many short ticks give the same milestones. Offline progress is a normal tick, so its events come as in play. An event costs one dictionary lookup at a sale, and nothing more after the first sale. A load sends no event.

**A load raises each milestone that the state shows.** `from_snapshot` raises each milestone to what the rest of the state shows, such as the first factory of each color in the run or each tier up to the transport tier. A save that the game made shows nothing more, so this changes nothing for it. A save from before #25 gets these milestones in this way. The migration `add_milestones` adds only the first sale, from its traces (capacity used or saturation). The count of prestiges of an older save is lost, so it starts at 0.

**A milestone id is kept for life.** The load checks each id against the content, as it checks colors and research. An id stays in the save after a prestige. So a content change that removes or renames a color, a transport tier, a research, or a prestige upgrade needs a migration that renames or removes its milestone. Otherwise each save that reached it fails to load.

**An imported code grants nothing that only the import gave.** An export code (ADR-0010) can come from another player. A platform cannot take an achievement back, so the milestones of an imported code must not unlock achievements on the platform account of this device. The player's own progress after the import must still unlock them.

The rule: after the player imports a code, the screen calls `Simulation.mark_milestones_imported()`. It records the value of each milestone at that time (`imported_milestones()`, the `imported` value of each entry in the snapshot, 0 when there was no import). An achievement for a milestone and a value (`at_least`) is granted only when the milestone has that value and the import did not have it:

```text
is_earned(value, imported) = value >= at_least and at_least > imported
```

The tracker uses this rule for an event and when it attaches, so a restart gives the same unlocks as play. Examples, with an imported code that has the first sale and 1 prism:

- "First sale" and "First prism" are never granted on this game. A first that the import had does not go up again.
- The player buys a second prism: "Two prisms" is granted, because the import did not have 2.
- A prestige keeps the record of the import, as it keeps the milestones.

**A cloud load is not an import.** A cloud save (ADR-0018) also uses the export code, but it is the player's own game from another device. The screen calls `mark_milestones_imported()` only for the import of the Export or import dialog, not when the cloud save replaces the game, and not when the player changes to the kept save. The record of an import is in the save, so the cloud carries it: when the other device of the player imported a code, this device does not grant its achievements either. A record beside the save, such as the cloud sync record, would not travel with the cloud save, so we keep it in the core state.

The rule has costs:

- The game cannot tell a code of the player's own game from a code of another player. A player who moves their own game by an export code, and not by a cloud save, does not get its achievements on the new platform account, until each milestone goes above the code.
- Each milestone of the game on the device before the import is replaced, so it is not part of the record. The platform account has those achievements already, if the platform was available.
- A player can edit a code to remove the record. The code has a checksum, not a signature (ADR-0010), so this does not stop a player who wants to cheat.

**Achievements are data outside the core.** `data/achievements.json` maps each achievement to a milestone and a value (`at_least`), and has the id of the achievement on each platform. The core does not read it. `AchievementList` checks it against the milestone ids of the content.

**One interface, one adapter for each platform.** `AchievementService` (`src/platform/achievements/`) has `unlock(def) -> bool`, `is_available()`, `poll()`, and the signal `became_available`. `AchievementTracker` listens to the simulation and unlocks through the service. Each platform unlock is idempotent, so a second unlock changes nothing. `TestAchievementService` keeps the unlocks in memory. The game uses it when the device has no platform SDK, so the game runs with no service. The Steam, Game Center, and Google Play Games adapters get their SDK or plugin as an object and call it by name, so they parse and do nothing in a build with no SDK, and tests can give them a fake. `PlatformSdks` (`src/platform/`) starts each SDK once for the achievements and the cloud save. An unlock that the platform answers later and that fails is logged, and the tracker sends it again at the next start. A person must still run each adapter on its platform (`docs/achievements.md`).

We rejected two other designs:

- **Events only, with no record.** It is smaller, but a moved save, an older save, and an unlock that failed give no achievement.
- **Achievements as conditions on the state.** No core change is needed, but the state does not keep a sale or a prestige count, and a prestige clears most of the run.
