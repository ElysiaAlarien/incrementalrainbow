# The save is versioned JSON of the snapshot, with strict loads and migrations

The save is JSON: `{"format": "incremental-rainbow-save", "version": N, "state": ...}`, where the state is `Simulation.snapshot()`. `SaveCodec` (in `src/core/save/`) writes and reads it, and `SaveFile` (in `src/platform/`) keeps it in `user://save.json`. We chose JSON, as for content (ADR-0007), because it is engine-neutral, easy to read when a player reports a bad save, and safe to parse from an untrusted export code later. We rejected `var_to_str` and `var_to_bytes` because they tie the format to Godot's Variant encoding, and `str_to_var` can make objects. JSON has one number type, so whole numbers are exact only up to 2^53; the load rejects any number that is not whole and exact.

A load makes a new `Simulation` through `Simulation.from_snapshot`, the inverse of `snapshot()`, so a failed load cannot change the current game. The load is strict: each value must be present and valid, or the load fails with the path of the value, such as `state.factories[1].color`. It does not fill in defaults, because a default can hide a value that save or load forgot.

Each change to the shape of the state (a value added, removed, renamed, or changed in meaning) adds one migration step to `SaveCodec.migrations()`. The version number is the count of steps plus one, so it cannot fall out of step with the migrations. A step turns the state of one version into the next. A save of a newer version than the game fails; it does not load partly.

We save only the random number generator state, not the seed, because the seed only sets the first state and plays no other part in the rules.

The tests keep this correct as the core grows: a round trip of a game with a non-default value in every part of the state, generic tests that remove each value or give it the wrong kind and expect a failure, and a committed save of each version in `tests/fixtures/saves/` that must load in every later version of the game.
