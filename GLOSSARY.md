# Incremental Rainbow

An incremental game where the player builds factories that make colored widgets, sells them into a changing market, and manages the logistics of feeding mixed-color factories.

## Colors

**Color**:
The single property that sets a widget apart. Colors follow the painter's model, where red, yellow, and blue mix to make the others.
_Avoid_: Hue, paint, dye

**Primary color**:
Red, yellow, or blue.

**Base color**:
A color whose factory needs no inputs: red, yellow, blue, white, or black.

**Secondary color**:
Green, orange, or purple. Each one is mixed from two primary colors.

**Tertiary color**:
One of six colors mixed from a primary color and an adjacent secondary color, such as red-orange.

**Brown**:
The neutral color mixed from all three primary colors.

**Tint**:
A color mixed from a hue and white.

**Shade**:
A color mixed from a hue and black.

**Recipe**:
The set of input widgets that a factory of a given color consumes to make one widget of that color.
_Avoid_: Formula, combination

**Symbol**:
The shape shown with a color, such as a square for red, so that a colorblind player can tell colors apart. Each color has its own symbol.
_Avoid_: Icon, glyph

## Production

**Widget**:
One unit of product with exactly one color.
_Avoid_: Item, unit, good

**Factory**:
A building that makes widgets of one color. Its size is how many production lines it has. A base factory makes a base color from nothing. Any other factory consumes the inputs of its recipe.
_Avoid_: Machine, producer, plant

**Production line**:
One unit of a factory's capacity to make widgets. A new factory has one line, and the player pays money to add more. Each line makes widgets at the same rate, so a factory with more lines makes more widgets in the same time.
_Avoid_: Assembly line, worker, slot

**Output bay**:
The small space where a factory holds its finished widgets until transport moves them. When it is full, the factory stops.
_Avoid_: Buffer, output storage

**Input bay**:
The small space where a mixed factory holds incoming widgets of one input color until it consumes them.
_Avoid_: Input buffer, hopper

**Consume**:
To use a widget as a recipe input. A consumed widget is gone and cannot be sold.
_Avoid_: Spend, burn

## Logistics

**Warehouse**:
A building, unlocked later in a run, that holds widgets of one color between their source and their destination, so its outflow can differ from its inflow. Links go into it from factories, and out of it to markets and mixed factories. Its space is how many widgets it holds.
_Avoid_: Storage, inventory, stockpile

**Link**:
One route that moves widgets of one color from a source to a destination. At the start of a run, links go from factories directly to a market or to other factories. Later, links also go to and from warehouses.
_Avoid_: Route, belt, connection

**Transport**:
The movement of widgets along a link. Transport always has a cost. Early in a run, the player must start it by hand, and automatic transport is an upgrade.
_Avoid_: Trucks, shipping, bandwidth

**Transport tier**:
The level of vehicle technology the player has bought, such as carts, trucks, or trains. A higher tier reaches more remote markets.
_Avoid_: Vehicle level, transport tech

**Vehicle**:
The transport tier that one link uses. A new link gets the player's transport tier as its vehicle. A link keeps its vehicle until the player pays to upgrade it to the player's transport tier.
_Avoid_: Carrier, truck

**Shipment**:
One batch of widgets that moves along a link. It costs money and takes the link's transit time to arrive.
_Avoid_: Delivery, trip, load

**Automatic transport**:
An upgrade that the player buys for one link. An automatic link starts a shipment by itself once each transit time of its vehicle. If there is nothing to ship or too little money, it sends nothing that time.
_Avoid_: Auto-ship, autopilot

**Throughput**:
The number of widgets that started on a link in the last minute. It shows where widgets cannot move fast enough. A warehouse has an inflow and an outflow throughput: the throughput of its links in and of its links out.
_Avoid_: Flow, rate

**Split**:
The percentage of a color's widgets that the player sends to each of that color's links.
_Avoid_: Allocation, ratio, distribution

**Sell threshold**:
The demand level below which a warehouse holds a color instead of sending it to a market.
_Avoid_: Reserve price, floor

## Unlocks

**Research**:
Progress inside a run that unlocks new recipes, colors, and forecast accuracy.
_Avoid_: Tech, upgrades

**Lab**:
A building that consumes widgets delivered by link to pay for research.
_Avoid_: Research center, library

**Selected research**:
The one research that labs pay for now. The player selects it. Research keeps what was paid for it when the player selects other research.

**Lab stock**:
Widgets that arrived at a lab when the selected research did not need them. They pay for the next selected research that needs them, so no widget is lost.
_Avoid_: Research buffer, lab inventory

## Market

**Money**:
The currency the player earns by selling widgets and spends to build and upgrade.
_Avoid_: Cash, coins, gold

**Market**:
A destination where widgets are sold. Each market has its own consumer behavior and capacity. A run starts with one market, and the player expands to more.
_Avoid_: Seller, shop, store, outlet

**Remoteness**:
How hard a market is to reach. A market is open only when the player's transport tier is high enough for its remoteness.
_Avoid_: Distance, range

**Capacity**:
The total number of widgets of all colors that a market can buy in one period.
_Avoid_: Sales limit, throughput

**Period**:
The fixed span of time in which a market's capacity applies. Periods follow each other from the start of the game, with no gap. At the start of each period, the capacity used goes back to zero. The spec does not set the length of a period yet, so it is a placeholder in the data.
_Avoid_: Cycle, round, turn

**Capacity used**:
The widgets that a market sold in the current period. A shipment carries only the capacity that is left when it leaves: the capacity less the capacity used and less the widgets already on their way to that market.

**Community investment**:
Money the player spends in a market to grow its population or its income.
_Avoid_: Market upgrade, capacity upgrade

**Population**:
How many consumers a market has.

**Income**:
How much the consumers in a market can earn and spend.
_Avoid_: Wealth, purchasing power

**Sell**:
To exchange widgets for money at a market, at that market's current price for their color.

**Demand**:
How much a market currently values a color. It sets that color's price there.
_Avoid_: Popularity, price level

**Forecast**:
The player's view of future demand. It starts nearly random, and upgrades make it more accurate.
_Avoid_: Prediction, projection

**Drift**:
The slow, continuous change of each color's demand over time.

**Saturation**:
The drop in a color's demand caused by the player's own recent sales of that color in that market. It recovers over time.

**Demand event**:
A short, named spike or crash in the demand for one or more colors.
_Avoid_: Trend, craze

## Progression

**Run**:
One playthrough from a fresh start up to a prestige.

**Prestige**:
A voluntary reset of a run. The player can prestige only when they own at least one prism. A prestige keeps prisms, prestige upgrades, their unlocks, and the prism price, and starts a fresh run with all else as in a new game. See ADR-0012.
_Avoid_: Rebirth, ascension, reset

**Prism**:
The permanent currency that the player buys during a run and spends on prestige upgrades.
_Avoid_: Prestige points, gems

**Prestige upgrade**:
A permanent bonus or unlock bought with prisms. It lasts across all later runs.
_Avoid_: Perk, talent, meta upgrade

**Offline progress**:
Production, logistics, and sales that happen while the game is closed, applied when the player returns.

## Saves

**Save**:
The versioned, serialized form of the core state that the game keeps on the device. The export code and each platform's cloud save hold the same save.
_Avoid_: Save file, save game, profile

**Export code**:
The save as text that the player copies to another device and imports there, with the save version and a checksum. See ADR-0010.
_Avoid_: Save string, save key, backup code

**Migration**:
One step that turns a save of one version into a save of the next version, so that old saves still load.
_Avoid_: Upgrade, conversion
