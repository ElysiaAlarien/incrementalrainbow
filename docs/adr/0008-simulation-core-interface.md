# The simulation core interface

`Simulation` (in `src/core/`) holds all game rules and extends `RefCounted`. No core script may be a `Node`, and a test enforces this. The rest of the game talks to the core only through three kinds of calls:

- **Commands** are typed methods, such as `build_factory(color)`. Each returns a `CommandResult`. A command checks everything before it changes anything, so a command that is not allowed returns `ok == false` with a `reason` enum value and a readable `message`, and the state does not change.
- **`tick(duration_ms)`** advances time by an integer number of milliseconds. Time and production progress are integers, so one long tick gives the same state as many short ticks. Offline progress depends on this. Each tick takes time in proportion to the size of the state, not to the duration.
- **Queries** return copies, such as `FactoryView`, never live state. `snapshot()` returns the full state as plain data, to compare states in tests.

The same content, seed, commands, and ticks always give the same state.

To load a save, the game makes a new simulation from saved state. ADR-0009 adds this entry point.
