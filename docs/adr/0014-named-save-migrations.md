# A save lists the named migrations that its state has

This ADR supersedes the version number part of ADR-0009. The rest of ADR-0009 (JSON, the strict load, and the tests) does not change.

Before, a save had one `"version": N`, and the migrations were one ordered list in `SaveCodec`. Each feature that changed the state added the next step and the next version. Feature branches that were open at the same time all took the same N, so each one had to rebase and take a new number after the one before it merged. The last group of eight branches each added version 7.

**Each migration is a file.** A migration is a script in `src/core/save/migrations/` that extends `SaveMigration`. The file name is the name of the migration, for example `add_warehouses`. `SaveMigrations.found()` reads the folder (`ResourceLoader.list_directory`, which also works in an exported game), so a new migration adds a file and changes no shared list. Do not rename a file after a save can list it.

**A save lists the migrations that it has.** The save is `{"format": ..., "version": 14, "applied": [...], "saved_at_unix_ms": T, "state": ...}`. `"applied"` has the name of each migration that the state has. A load runs each migration that the game knows and the save does not list. Then the next save lists all of them.

**Needs set the run order.** A migration can list the migrations that it needs (`SaveMigration.needs()`). The run order puts each migration after the migrations that it needs. Where no need decides, the order is by name. The order is the same on each load and on each device. It does not depend on the order in which the engine lists the files. A test fails on a need that is not a migration, on migrations that need each other in a loop, and on two migrations with the same name.

**A later migration needs `add_save_time`.** The 12 migrations of the numbered versions (`SaveCodec.NUMBERED_MIGRATIONS`) are a chain: each one needs the one before it. Each later migration must need `add_save_time`, the last of the chain, directly or through other migrations. It always gets the state of version 13 or later. It never runs between two old migrations on a save of an old version. A test checks this.

**Independent migrations must give the same state in either order.** Two migrations of which neither needs the other run by name, but the order must not matter. A test runs each such pair in both orders on the state of each fixture and compares the results. If two migrations change the same value, one of them must need the other. Each branch alone has no new pair, so this test can fail first on `main`, after the second of two branches merges.

**Old saves still load.** A save of version 1 to 13 has no `"applied"` list. It has the first N - 1 names of `NUMBERED_MIGRATIONS`, which is the same state as before. The version 1 to 13 fixtures stay as tests.

**The version is now the version of the save format.** It is 14 for each save with an `"applied"` list. It changes only when the format around the state changes, not for a change to the state. A game of version 13 or older reads a version 14 save as a save of a newer game, so an old game does not load a new save in part. A save of a version above 14 fails with the "newer version" message.

**A save that lists a migration that the game does not know fails** with the "newer version" message (`LoadResult.Reason.NEWER_VERSION`). It does not load in part. The load also fails as damaged (`BAD_VERSION`) in three cases: `"applied"` is not a list of names, it lists a name twice, or it lists a migration but not a migration that it needs. The game never writes such a list. If the load ran the missing need after the migration that needs it, the state could be wrong.

**The export code (ADR-0010) holds the same save.** Its version is the save format version, so it is now 14 for each code, and the prefix catches only a newer format. The import finds a newer game from the `"applied"` list in the save, and it gives the export code message ("Update the game, then import the code again"). A code that fails after its migrations ran gets the message that it is from an older version of the game (`LoadResult.migrated`).

**The save time** is read from a save of version 13 or later, as before. Each save with an `"applied"` list has it.

We rejected two other designs:

- **Keep one number and merge in order.** It is simple, but each open branch must rebase and change its number after each merge. This was the cost that this ADR removes.
- **A number for each feature area, or a timestamp for each step.** It removes the clash of numbers, but it still needs one global order. A branch cannot know that order before it merges. If two branches pick numbers out of order, a save cannot tell which steps it has.

## Adding a migration

See `docs/agents/save-migrations.md`.
