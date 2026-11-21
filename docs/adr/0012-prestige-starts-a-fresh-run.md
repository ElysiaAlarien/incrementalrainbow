# A prestige starts a fresh run and keeps only a named set

A prestige makes a new `Simulation` with `Simulation.new`, the same path as a new game. Then the old simulation takes all members of the new one, except the members in `Simulation._PRESTIGE_KEEPS`. So a prestige clears all state by default, and the keep set is the one place that says what lasts across runs. Today the keep set is prisms and the prism price (the count of prisms bought, ADR-0003). Prestige upgrades and their unlocks join it when they exist.

We rejected a method that clears each run value by hand. Each feature that adds run state would have to change that method, and a value that it forgot would carry over to the next run with no error. With a fresh run from `Simulation.new`, a feature that adds run state needs no change to prestige. A test compares the snapshot after a prestige with the snapshot of a new game, less the keep set and the random values. So it fails if a prestige keeps saved state that is not in the set. State that is not in the snapshot is not saved, so ADR-0009 already makes all real state part of the snapshot.

The copy uses the list of script members of `Simulation`. Thus all state of the core must be in members of `Simulation`, or in objects that those members hold. A static variable would not clear. An object that holds a reference back to its `Simulation` (or a Callable bound to it) would point at the discarded new simulation, so core state objects must not hold one.

The old run's random number generator seeds the new run, so the same commands and ticks give the same new run (ADR-0006). The new run starts again at time 0.

The spec does not say if a prestige keeps the transport tier, vehicles, open markets, community investment, demand, and saturation. They are part of the run, so a prestige clears them. To keep one of them, add its members to the keep set.

`_PRESTIGE_CLEARS` holds the names of what a prestige clears, for the player. It does not control what clears, so a feature that adds run state adds its name there only so that the player sees it. A test maps each snapshot key to a name in the keep set or in this list, so it fails when a feature adds a snapshot key and no name for it.
