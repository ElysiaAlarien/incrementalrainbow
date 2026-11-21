class_name ShipmentView
extends RefCounted
## A read-only copy of one shipment in transit on a link.

## How many widgets the shipment carries.
var count: int
## Time until the shipment arrives.
var remaining_ms: int
