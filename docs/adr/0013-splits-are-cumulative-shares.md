# A split is a cumulative share of the source's widgets, and it holds back widgets for a blocked link

A split sets the percentage of a source's widgets of one color that goes to each of its links. Each automatic link starts a shipment on its own grid, at its own time (ADR-0008 and #7), so a split cannot cut one batch of widgets into parts. The rule is in `Simulation._split_allowance`.

**The rule.** Each link of a split counts the widgets it shipped since the player set the split. When a link starts a shipment, the total is the widgets that all links of the split shipped plus the widgets in the source now. The link may carry its percentage of that total, rounded down, less what it shipped. Then the shipment size rule (what the destination accepts) limits it as before. All values are integers, so one long tick gives the same state as many short ticks.

We rejected two other rules:

- **A share of the widgets in the source at each start.** The link that starts first takes its percentage of what is there, and the next link takes its percentage of the rest. The result depends on the order and the times of the starts, not on the percentages.
- **Separate output bays for each link.** The factory puts each widget in the bay of one link. This changes the output bay, which is one bay in the glossary and the spec, and a full bay of one link would stop the factory as the rule above does.

**A blocked link keeps its share.** When a link cannot take widgets (its destination is full or it has too little money), its share waits in the source. The other links do not get it. If it waits too long, the source fills and stops. The player sees a full output bay and the link that does not ship, as for any other bottleneck. When the link can take widgets again, it catches up to its share. We chose this because the player set the percentages, and a split that sends more to the other links when one is blocked does not do what the player said.

**A shipment by hand is outside the split.** The player can start a shipment by hand on any link of a source with a split, also on a link at 0%. It takes any widgets in the source, and they do not count in the split. Widgets that it takes leave the source, so they are not in the total, and the percentages apply to the widgets of automatic starts. We chose this because the player starts a shipment by hand on purpose, and a split must not block it.

**The split is on the links.** Each link has a split percentage (or none) and its shipped count. The links from one source (a factory or a warehouse) with one color share a split, and `LinkState.same_source_as` is the only place that compares sources. It compares `LinkState.source_key()`. A source with a split gives 0% to the automatic links that the player left out, and to links that are manual or new (they keep 0% when they become automatic). Thus the automatic starts of a source with a split follow percentages that always add up to 100. A new split, and a cleared split, count from 0.
