# A prestige starts a fresh run and keeps only a named set

A prestige makes a new `Simulation` with `Simulation.new`, the same path as a new game, and copies only the members in `Simulation._PRESTIGE_KEEPS` into it. Then the old simulation takes all members of the new one. So a prestige clears all state by default, and the keep set is the one place that says what lasts across runs. Today the keep set is prisms and the prism price (the count of prisms bought, ADR-0003). Prestige upgrades and their unlocks join it when they exist.

We rejected a reset method that clears each run value by hand. Each feature that adds run state would have to change that method, and a value that it forgot would carry over to the next run with no error. With a fresh run from `Simulation.new`, a feature that adds run state needs no change to prestige. A test compares the state after a prestige with a new game, less the keep set and the random values, so it fails if a prestige keeps something that is not in the set.

The copy uses the list of script members of `Simulation`. Thus all state of the core must be in members of `Simulation`, or in objects that those members hold. A static variable would not reset.

The old run's random number generator seeds the new run, so the same commands and ticks give the same new run (ADR-0006). The new run starts again at time 0.

The spec does not say if a prestige keeps the transport tier, vehicles, open markets, community investment, demand, and saturation. They are part of the run, so a prestige clears them. To keep one of them, add its members to the keep set.

`_PRESTIGE_CLEARS` holds the names of what a prestige clears, for the player. It does not control the reset, so a feature that adds run state adds its name there only so that the player sees it.
