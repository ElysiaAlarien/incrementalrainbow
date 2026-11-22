# The simulation core interface

`Simulation` (in `src/core/`) holds all game rules and extends `RefCounted`. No core script may be a `Node`, and a test enforces this. The rest of the game talks to the core only through three kinds of calls:

- **Commands** are typed methods, such as `build_factory(color)`. Each returns a `CommandResult`. A command checks everything before it changes anything, so a command that is not allowed returns `ok == false` with a `reason` enum value and a readable `message`, and the state does not change.
- **`tick(duration_ms)`** advances time by an integer number of milliseconds. Time and production progress are integers, so one long tick gives the same state as many short ticks. Offline progress depends on this: `progress_offline(duration_ms)` is a tick that also returns a summary of what happened. Inside a tick, events (such as shipment arrivals and automatic shipment starts) happen in time order, and production advances exactly between them. Each tick takes time in proportion to the size of the state and the number of events in it, not to the duration alone.
- **Queries** return copies, such as `FactoryView`, never live state. `snapshot()` returns the full state as plain data, to compare states in tests.

At first, a tick had a cost in proportion to the size of the state only. Automatic transport (#7) changed this. Money is a float sum (ADR-0005), so the order of sales sets the result, and only one event at a time gives the same money as many short ticks. A closed form for a long tick would give a different sum. If offline progress is too slow on a phone, make the event loop faster (for example, a queue of events), but keep the one-event-at-a-time order.

Offline progress (#22) has no rule of its own. It is a normal tick for the time away. Manual transport is off by its nature, because only a command starts a manual shipment. To make a long time away faster, #22 changed two things in the tick, and the order of events stayed the same:

- The tick keeps its events (arrivals, demand event starts, and automatic starts) in a queue, sorted by time (`EventQueue`). The tick makes the queue again at its start. Thus each event costs a small, fixed amount of time, not a pass over all links.
- A factory makes widgets only up to each event that uses it. `_factory_state` brings the factory up to the current time. Thus an event does not advance all factories.

A rule inside a tick must get a factory through `_factory_state`. A new kind of event goes into the queue.

Offline progress still costs time for each shipment, because each sale has its own price (ADR-0011) and money is an ordered float sum. We found no exact way to skip time. A day away for a large game takes minutes on a phone. So the user decided on a cap: offline progress applies at most `offline.max_time_away_ms` of time away (24 h, in `balance.json`). Time away above the cap gives no progress, and the summary tells the player. `offline_progress_ms(time_away_ms)` applies the cap in the core.

The same content, seed, commands, and ticks always give the same state.

To load a save, the game makes a new simulation from saved state. ADR-0009 adds this entry point.
