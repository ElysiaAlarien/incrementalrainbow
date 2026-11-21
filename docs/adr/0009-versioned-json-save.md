# The save is versioned JSON of the snapshot, with strict loads and migrations

The save is JSON: `{"format": "incremental-rainbow-save", "version": N, "state": ...}`. The state is `Simulation.snapshot()`. `SaveCodec` (in `src/core/save/`) writes and reads the save. `SaveFile` (in `src/platform/`) keeps it in `user://save.json`.

We chose JSON, as for content (ADR-0007). It is engine-neutral, and it is easy to read when a player reports a bad save. It is also safe to parse from an untrusted export code later. We rejected `var_to_str` and `var_to_bytes`, because they tie the format to Godot's Variant encoding, and `str_to_var` can make objects. JSON has one number type, so whole numbers are exact only up to 2^53. The load rejects a number that is not whole and exact.

This adds one entry point to the core interface of ADR-0008. A load makes a new `Simulation` through `Simulation.from_snapshot`, the inverse of `snapshot()`. `SaveCodec.decode` is the only caller, and the UI calls `SaveCodec`, not `from_snapshot`. Because a load makes a new simulation, a failed load cannot change the current game.

The load is strict. Each value must be present and valid, or the load fails with the path of the value, such as `state.factories[1].color`. The load does not fill in defaults, because a default can hide a value that save or load forgot.

One exception: the state of each market (#10) is a list keyed by the market id from the content. A market that the list does not have starts as in the content at the start of a run. A migration step gets no content, so it cannot write the start values of each market, and content can add markets later (#11, #12) with no change to the shape of the state. The load still fails on a market id that the content does not have, on a market that is in the list twice, and on each missing or bad value inside a market that the list has.

Each change to the shape of the state adds one migration step to `SaveCodec.migrations()`. A change is a value that is added, removed, renamed, or changed in meaning. A step turns the state of one version into the state of the next version. The version number is the count of steps plus one, so the version and the migrations always agree. A save of a newer version than the game fails. It does not load in part.

We save only the state of the random number generator, not the seed. The seed only sets the first state, and no rule uses it after that.

These tests keep the save correct as the core grows:
- A round trip of a game that has a value that is not the default in each part of the state.
- Generic tests that remove each value, or give it the wrong kind, and expect a failure.
- A committed save of each version in `tests/fixtures/saves/`. It must load in each later version of the game.
