# Demand is a function of time and of recent sales

The demand of a color in a market is drift times saturation, and its price is the base price times demand. `DemandState` (in `src/core/state/`) holds the rules.

**Drift is a pure function of time.** At the start of a game, the core draws one u32, the drift key, from its random number generator. The key, a hash of the market and color ids, and a knot index seed a `SimRng` that gives the value of that knot. Drift moves smoothly (smoothstep) from one knot to the next, once each `drift_period_ms`. We rejected a random walk that draws from the generator on each tick, for three reasons:

- One long tick must give the same state as many short ticks (ADR-0008). A draw on each tick breaks this, unless time is cut into fixed steps.
- Each tick must take time in proportion to the size of the state, not the duration. Fixed drift steps make offline progress for a day cost one step for each period of that day.
- The demand at a future time is known. The forecast can show this true demand with noise that research removes. Demand events and other rules that draw from the generator do not change drift.

A knot value depends only on the key, the ids, and the index. So a change to the drift rule, the hash, or the ids of markets and colors changes the demand of every saved game. The version 3 save fixture pins drift values, so such a change fails a test, and it needs a save migration.

**Saturation is the time when it has fully recovered.** For each color in each market that has saturation, the state holds `saturated_until_ms`. A sale of n widgets at time t sets it to `max(saturated_until_ms, t) + n * saturation_ms_per_widget`. Saturation recovers at a constant rate, so the recent widgets that it still holds at time t are `(saturated_until_ms - t) / saturation_ms_per_widget`, and its factor is `1 / (1 + widgets / saturation_half_widgets)`. All of the state is integer time, so it is exact, and a tick changes it only to forget saturation that has fully recovered. We rejected exponential recovery, because a decay on each tick is not exact in floats across tick lengths, and because `pow` and `exp` can give different bits on different platforms.

**A sale uses the demand at the arrival of its shipment**, which can be before the end of a long tick. All widgets of one shipment sell at one price, and then the sale saturates.
