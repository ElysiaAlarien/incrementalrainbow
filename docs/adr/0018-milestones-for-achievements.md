# The core records milestones, and platform achievements react to them

Platform achievements (#25) for Steam, Game Center, and Google Play Games must react to core events (spec #1). They sit outside the core, behind one interface.

**The core records milestones in the save.** A milestone is a lifetime record of something the player did: the first time they did it (value 1), or the highest count they reached. A milestone only goes up. `Simulation._milestones` holds them, `milestones()` reads them, and the snapshot key is `milestones` (a list of `{"id", "value"}`, sorted by id). A prestige keeps them (`_PRESTIGE_KEEPS`, ADR-0012). `src/core/milestones.gd` has the ids. Some ids have one id for each item of the content, such as `factory.brown` or `research.earth_tones`.

We record them, not only send events, for three reasons:

- The player gets the achievements of a save that moves to another device by an export code (ADR-0010) or a cloud save. The other platform never saw the events.
- A platform that is not available (no sign-in, no network) gets the unlocks later. The tracker unlocks all that the milestones grant at each start, and when the service becomes available.
- Counts such as the prestiges are not in the rest of the state.

**The core sends an event when a milestone goes up.** `Simulation.milestone_reached(id, value)` is a signal, so it adds one kind of call to ADR-0008. Commands and tick events raise milestones where the change happens: a sale, a completed research, a prestige. No rule samples the state at the end of a tick, so one long tick and many short ticks give the same milestones. Offline progress is a normal tick, so its events come as in play. An event costs one dictionary lookup at a sale, and nothing more after the first sale. A load sends no event.

**A load raises each milestone that the state shows.** `from_snapshot` raises each milestone to what the rest of the state shows, such as the first factory of each color in the run or each tier up to the transport tier. A save that the game made shows nothing more, so this changes nothing for it. A save from before #25 gets these milestones in this way. The migration `add_milestones` adds only the first sale, from its traces (capacity used or saturation). The count of prestiges of an older save is lost, so it starts at 0.

**Achievements are data outside the core.** `data/achievements.json` maps each achievement to a milestone and a value (`at_least`), and has the id of the achievement on each platform. The core does not read it. `AchievementList` checks it against the milestone ids of the content.

**One interface, one adapter for each platform.** `AchievementService` (`src/platform/achievements/`) has `unlock(def) -> bool`, `is_available()`, `poll()`, and the signal `became_available`. `AchievementTracker` listens to the simulation and unlocks through the service. Each platform unlock is idempotent, so a second unlock changes nothing. `TestAchievementService` keeps the unlocks in memory. The game uses it when the device has no platform SDK, so the game runs with no service. The Steam, Game Center, and Google Play Games adapters call their SDK or plugin by name through `Engine.get_singleton`, so they parse and do nothing in a build with no SDK. They are skeletons until a person finishes them on each platform (`docs/achievements.md`).

We rejected two other designs:

- **Events only, with no record.** It is smaller, but a moved save, an older save, and an unlock that failed give no achievement.
- **Achievements as conditions on the state.** No core change is needed, but the state does not keep a sale or a prestige count, and a prestige clears most of the run.
