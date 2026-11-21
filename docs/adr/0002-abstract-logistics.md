# Abstract logistics with no map

Logistics has no spatial layout. There is no grid, no map, and no placement. Transportation and storage are capacities that the player buys and upgrades, and bottlenecks come from throughput, not distance. We rejected a tile grid because it is hard to use on a phone, and a node map because it adds placement work that does not fit an incremental game.

The one exception is market remoteness: each market has a single remoteness number that sets which transport tier can reach it. It is not a position, and factories and warehouses have no remoteness. Do not add positions or distances to anything else without revisiting this decision.
