# Incremental Rainbow

An incremental game where the player builds factories that make colored widgets, sells them into changing markets, and manages the logistics of feeding mixed-color factories. Made with Godot 4.7.

## Layout

- `src/core/`: the headless simulation core. All game rules live here, with no scene-tree dependency.
- `src/ui/`: scenes and scripts that show the core and send it commands.
- `data/`: game content as JSON (colors, symbols, recipes, and balance values).
- `tests/unit/`: core tests. `tests/smoke/`: UI smoke tests.
- `addons/gut/`: the GUT test runner (vendored).
- `docs/adr/`: architecture decisions.

## Run the tests

Install Godot 4.7, then run:

```bash
GODOT=/path/to/godot tools/test.sh
```

To run one test script, add `-gselect=test_big_number.gd`. CI runs the same script on each pull request.
