# A sell threshold holds the automatic starts from a warehouse to a market, by the demand at each start

A warehouse can have a sell threshold: a whole percent of normal demand, as the screen shows demand. The rule is in `Simulation._is_held`.

**The rule.** When an automatic start on a link from a warehouse to a market is due, the core reads the demand for the link's color in that market at that time. It rounds the demand to a whole percent, as the screen does (`MarketView.demand_percent`). If that percent is below the threshold, the start sends nothing, and the link's status is "held". The next automatic start, one transit time later, reads demand again. Equal demand does not hold. Thus the player sees the hold start and end at the number that they set.

**Each market is separate.** One warehouse can hold its color from one market and send it to another market that has higher demand. Links to mixed factories and labs never hold, because the threshold is about the price that a market pays.

**The hold ends at the next automatic start.** There is no event for the time when demand goes back up. Demand drifts slowly, and a link starts once each transit time, so the hold ends at most one transit time late. An event would need the time at which drift, saturation, and demand events cross the threshold, and it would add work to each tick.

**Ticks and offline progress need no special rule.** Demand is a function of time and of sales (ADR-0011), and the hold reads it at the time of each start, inside the event loop of the tick (ADR-0008). So one long tick, many short ticks, and offline progress give the same holds.

**A held link of a split keeps its share** (ADR-0013). A held start ships nothing, so the link's share waits in the warehouse, and the other links do not get it. When demand goes back up, the link catches up to its share. If the hold lasts, the warehouse fills, and the links into it stop. This is what the player asked for: hold that share for that market.

**A shipment by hand is outside the hold**, as it is outside the split (ADR-0013). The player starts it on purpose, so a threshold must not stop it. The issue (#15) says that a held warehouse sends no widgets to that market; we read this as "sends none by itself".

**"Holds now" is read from demand now.** `WarehouseView.held_market_ids` gives the markets that the warehouse holds its color from now: those at the end of its automatic links whose demand is below the threshold. A manual link never holds. The status of the last automatic start can be one transit time old, so the warehouse row uses the query, and the link row shows the status of the last start.

We rejected two other rules:

- **Compare the demand without rounding.** A demand of 79.6% shows as 80%. With a threshold of 80%, it would hold while the screen shows 80%.
- **Hold the whole warehouse when the demand of any market is low.** A warehouse that feeds two markets would stop for both, and the player could not send the color to the market that pays more.
