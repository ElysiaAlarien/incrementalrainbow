# The guided start is core state in the save, and core events move it on

The guided start (#26) teaches a new player to build a factory, make a link to a market, start a shipment, and sell at a market. The player can skip it at any step. It must not show again after it is done or skipped.

**It is in the save, not in a setting of the device.** "No earlier play" is a property of the game, not of the device. The export code (ADR-0010) and each platform's cloud save hold the same save, so a player who moves a game to a new phone does not see the guide again. A device setting would show the guide again on each new device and after each reinstall, also for a game that is far along. It would also show nothing on a shared device for a second player's new game. The core has one member, `Simulation._guided_start`, with the step or the end (`done` or `skipped`). The snapshot key is `guided_start`. A save from before #26 is from earlier play, so the migration `add_guided_start` sets it to `done`.

**Core events move it on, not UI clicks.** The step moves on where the core makes the change: a factory is built, a link to a market is made, a shipment to a market starts (by hand or by automatic transport), and a market sells. So the guide is correct for each layout of the screen (#27 changes it), and in offline progress. An action moves the guide to the step after it, and so also completes each step before it. The UI only shows `Simulation.guided_start()` and sends `skip_guided_start()`.

**A prestige keeps it, and ends it first.** The guide is in `_PRESTIGE_KEEPS` (ADR-0012), so a prestige does not show it again. A guide that is not over at a prestige becomes `skipped`: a player who can prestige has played, and a later step does not fit a fresh run with no factories.

**The step text is in the UI.** The text says which controls to use, so it changes with the layout, not with the rules.
