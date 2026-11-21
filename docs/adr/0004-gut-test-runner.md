# GUT as the test runner

We use GUT 9 (Godot Unit Test), committed in `addons/gut/`, as the test runner. GUT is pure GDScript, runs headless from the command line with one call, writes JUnit XML for CI, and has years of use in Godot projects. We rejected gdUnit4 because its command-line runner needs a wrapper script and more setup in CI, and its extra features (scene runner, C# support) are not needed: the simulation core holds the rules and is tested without scenes.

GUT exits with 0 when a test script does not parse (it skips the script) or when no test runs. `tests/post_run_hook.gd` makes both cases fail. Run the suite with `tools/test.sh`, which imports the project first so that `class_name` lookups work on a fresh clone.
