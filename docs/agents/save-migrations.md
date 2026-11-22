# Adding save state

Read this when a ticket adds, removes, renames, or changes the meaning of a value in the core state (`Simulation.snapshot()`). The design is in ADR-0014. Follow these steps so that branches that are open at the same time do not conflict in the save code.

## Steps

1. **Add one migration file**: `src/core/save/migrations/<name>.gd`. The name says the change, for example `add_sell_thresholds`. Pick a name that no other open branch is likely to use. Do not edit `SaveCodec`, `SaveCodec.NUMBERED_MIGRATIONS`, or another migration.

   ```gdscript
   extends SaveMigration
   ## #15 adds a sell threshold to each warehouse. An older warehouse had none.


   func needs() -> Array[StringName]:
   	return [&"add_save_time"]


   func apply(state: Dictionary) -> Dictionary:
   	var warehouses: Variant = state.get("warehouses")
   	if warehouses is Array:
   		for warehouse: Variant in warehouses:
   			if warehouse is Dictionary:
   				warehouse.sell_threshold = -1
   	return state
   ```

2. **Set the needs.** List `add_save_time`, or a migration that needs it. Also list each migration of another feature that made a value that your migration reads or changes. If two migrations change the same value, one must need the other.
3. **Do not stop on damaged data** in `apply`. Check the type of each value before you change it, as above. The strict load checks the result.
4. **Commit the `.gd.uid` file** that Godot makes for the new script.
5. **Add a fixture**: `tests/fixtures/saves/<name>.json`, a save that the game of your branch wrote, with non-default values of the new state. Name it by the migration, not by a version number. The generic tests load each file in the folder and check the order of independent migrations on it.
6. **Add a test file of its own**: `tests/unit/save/test_<name>.gd`. Load the fixture and check the new values. Load an older fixture and check the values that the migration gives. Do not add these tests to the end of `test_save.gd`, because two branches that add to the end of one file conflict.

## Conflicts that remain

The save code does not conflict, but these places still can. Expect a small rebase for them:

- `_rich_game()` in `tests/unit/test_save.gd`, which must have a non-default value of each part of the state.
- `Simulation.snapshot()` and `Simulation.from_snapshot()`.
- ADR numbers in `docs/adr/` and entries in `GLOSSARY.md`.

After two branches with migrations merge, run the tests on `main`. The test that runs independent migrations in both orders can fail only when both are present.
