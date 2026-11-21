extends RefCounted
## Internal to the core. The mutable state of one link and its shipments in
## transit. Code outside src/core reads links through LinkView.

const LinkState := preload("res://src/core/state/link_state.gd")
const ShipmentState := preload("res://src/core/state/shipment_state.gd")

## Throughput counts the widgets that started on the link in this much time.
const THROUGHPUT_WINDOW_MS := 60_000

## Values of [member automatic_status]. The saved text of each must not change.
const MANUAL := &"manual"
const READY := &"ready"
const SHIPPED := &"shipped"
const NOTHING_TO_SHIP := &"nothing_to_ship"
const NOT_ENOUGH_MONEY := &"not_enough_money"
const AUTOMATIC_STATUSES: Dictionary[StringName, LinkView.Automatic] = {
	MANUAL: LinkView.Automatic.MANUAL,
	READY: LinkView.Automatic.READY,
	SHIPPED: LinkView.Automatic.SHIPPED,
	NOTHING_TO_SHIP: LinkView.Automatic.NOTHING_TO_SHIP,
	NOT_ENOUGH_MONEY: LinkView.Automatic.NOT_ENOUGH_MONEY,
}

## The name of each destination kind in a save.
const DESTINATION_NAMES: Dictionary[String, LinkView.Destination] = {
	"market": LinkView.Destination.MARKET,
	"factory": LinkView.Destination.FACTORY,
	"warehouse": LinkView.Destination.WAREHOUSE,
}

## The name of each source kind in a save.
const SOURCE_NAMES: Dictionary[String, LinkView.Source] = {
	"factory": LinkView.Source.FACTORY,
	"warehouse": LinkView.Source.WAREHOUSE,
}

var id: int
var color: StringName
var source_kind := LinkView.Source.FACTORY
## The factory at the start of the link, or 0 when it starts at a warehouse.
var source_factory_id: int
## The warehouse at the start of the link, or 0 when it starts at a factory.
var source_warehouse_id: int = 0
var destination_kind: LinkView.Destination
## The market at the end of the link, or &"" when it goes to another kind of
## place.
var destination_market_id: StringName = &""
## The factory at the end of the link, or 0 when it goes to another kind of
## place.
var destination_factory_id: int = 0
## The warehouse at the end of the link, or 0 when it goes to another kind of
## place.
var destination_warehouse_id: int = 0
## The transport tier id of the link's vehicle.
var vehicle: StringName
## Shipments in transit, in the order they started.
var shipments: Array[ShipmentState] = []
## [constant MANUAL], or what the last automatic start did: [constant READY]
## before the first one, then [constant SHIPPED], [constant NOTHING_TO_SHIP],
## or [constant NOT_ENOUGH_MONEY].
var automatic_status: StringName = MANUAL
## On an automatic link, the time of the next automatic start. 0 on a manual link.
var next_automatic_ms: int = 0
## The shipments that started in the last [constant THROUGHPUT_WINDOW_MS], in
## start order, each as [code][started_at_ms, count][/code].
var recent_starts: Array[PackedInt64Array] = []


func _init(p_id: int, p_color: StringName, p_source_factory_id: int, p_vehicle: StringName) -> void:
	id = p_id
	color = p_color
	source_factory_id = p_source_factory_id
	vehicle = p_vehicle


func is_automatic() -> bool:
	return automatic_status != MANUAL


## Makes the link automatic. The first automatic start is at [param now_ms].
func make_automatic(now_ms: int) -> void:
	automatic_status = READY
	next_automatic_ms = now_ms


## Records what the automatic start that is due now did, from the [param result]
## of the start, and sets the next one [param transit_time_ms] later.
func record_automatic_start(result: CommandResult, transit_time_ms: int) -> void:
	match result.reason:
		CommandResult.Reason.NONE:
			automatic_status = SHIPPED
		CommandResult.Reason.NOT_ENOUGH_MONEY:
			automatic_status = NOT_ENOUGH_MONEY
		_:
			assert(result.reason == CommandResult.Reason.NOTHING_TO_SHIP, "unexpected %s" % result.message)
			automatic_status = NOTHING_TO_SHIP
	next_automatic_ms += transit_time_ms


## Records a shipment of [param count] widgets that starts at [param now_ms].
func add_shipment(shipment_id: int, count: int, now_ms: int, transit_time_ms: int) -> void:
	shipments.append(ShipmentState.new(shipment_id, count, now_ms + transit_time_ms))
	forget_old_starts(now_ms)
	recent_starts.append(PackedInt64Array([now_ms, count]))


## Forgets the starts that are out of the throughput window at [param now_ms].
## A start that is out of the window stays out, so the result does not depend
## on when this runs.
func forget_old_starts(now_ms: int) -> void:
	while not recent_starts.is_empty() and recent_starts[0][0] <= now_ms - THROUGHPUT_WINDOW_MS:
		recent_starts.pop_front()


static func to_market(p_id: int, p_color: StringName, p_source_factory_id: int,
		market_id: StringName, p_vehicle: StringName) -> LinkState:
	var state := LinkState.new(p_id, p_color, p_source_factory_id, p_vehicle)
	state.destination_kind = LinkView.Destination.MARKET
	state.destination_market_id = market_id
	return state


static func to_factory(p_id: int, p_color: StringName, p_source_factory_id: int,
		factory_id: int, p_vehicle: StringName) -> LinkState:
	var state := LinkState.new(p_id, p_color, p_source_factory_id, p_vehicle)
	state.destination_kind = LinkView.Destination.FACTORY
	state.destination_factory_id = factory_id
	return state


static func to_warehouse(p_id: int, p_color: StringName, p_source_factory_id: int,
		warehouse_id: int, p_vehicle: StringName) -> LinkState:
	var state := LinkState.new(p_id, p_color, p_source_factory_id, p_vehicle)
	state.destination_kind = LinkView.Destination.WAREHOUSE
	state.destination_warehouse_id = warehouse_id
	return state


## Makes the link start at the warehouse [param warehouse_id] instead of a
## factory. Returns the link, so that it can follow [method to_market] or
## [method to_factory] with a source factory id of 0.
func from_warehouse(warehouse_id: int) -> LinkState:
	source_kind = LinkView.Source.WAREHOUSE
	source_factory_id = 0
	source_warehouse_id = warehouse_id
	return self


## True if the link starts at the factory [param factory_id].
func comes_from_factory(factory_id: int) -> bool:
	return source_kind == LinkView.Source.FACTORY and source_factory_id == factory_id


## True if the link starts at the warehouse [param warehouse_id].
func comes_from_warehouse(warehouse_id: int) -> bool:
	return source_kind == LinkView.Source.WAREHOUSE and source_warehouse_id == warehouse_id


## True if the link goes to the market [param market_id].
func goes_to_market(market_id: StringName) -> bool:
	return destination_kind == LinkView.Destination.MARKET and destination_market_id == market_id


## True if the link goes to the factory [param factory_id].
func goes_to_factory(factory_id: int) -> bool:
	return destination_kind == LinkView.Destination.FACTORY and destination_factory_id == factory_id


## True if the link goes to the warehouse [param warehouse_id].
func goes_to_warehouse(warehouse_id: int) -> bool:
	return destination_kind == LinkView.Destination.WAREHOUSE and destination_warehouse_id == warehouse_id


## What the link starts at, as [code][source_kind, id][/code], to compare links.
func source_key() -> Array:
	return [source_kind, source_factory_id if source_kind == LinkView.Source.FACTORY else source_warehouse_id]


## What the link goes to, as [code][destination_kind, id][/code], to compare
## links.
func destination_key() -> Array:
	match destination_kind:
		LinkView.Destination.FACTORY:
			return [destination_kind, destination_factory_id]
		LinkView.Destination.WAREHOUSE:
			return [destination_kind, destination_warehouse_id]
	return [destination_kind, destination_market_id]


## Widgets in all shipments in transit.
func widgets_in_transit() -> int:
	var count := 0
	for shipment in shipments:
		count += shipment.count
	return count


## The inverse of [method to_dict]. Records problems in [param reader]. Checks
## the ids that the content must know; the simulation checks the factories and
## warehouses at each end and the link id. [param now_ms], [param next_shipment_id], and
## [param shipment_ids] are for [method ShipmentState.from_snapshot].
static func from_snapshot(reader: SnapshotReader, content: Content, now_ms: int,
		next_shipment_id: int, shipment_ids: Dictionary) -> LinkState:
	var state := LinkState.new(reader.integer("id", 1), reader.text_id("color"), 0,
		reader.text_id("vehicle"))
	var source_name := reader.text_id("source_kind")
	if source_name != &"" and not SOURCE_NAMES.has(String(source_name)):
		reader.fail("source_kind", "must be one of %s, but it is \"%s\"" % [
			", ".join(SOURCE_NAMES.keys()), source_name])
	state.source_kind = SOURCE_NAMES.get(String(source_name), LinkView.Source.FACTORY)
	if source_name == &"factory":
		state.source_factory_id = reader.integer("source_factory_id", 1)
	elif source_name == &"warehouse":
		state.source_warehouse_id = reader.integer("source_warehouse_id", 1)
	var kind_name := reader.text_id("destination_kind")
	if kind_name != &"" and not DESTINATION_NAMES.has(String(kind_name)):
		reader.fail("destination_kind", "must be one of %s, but it is \"%s\"" % [
			", ".join(DESTINATION_NAMES.keys()), kind_name])
	state.destination_kind = DESTINATION_NAMES.get(String(kind_name), LinkView.Destination.MARKET)
	if kind_name == &"factory":
		state.destination_factory_id = reader.integer("destination_factory_id", 1)
	elif kind_name == &"warehouse":
		state.destination_warehouse_id = reader.integer("destination_warehouse_id", 1)
	elif kind_name == &"market":
		state.destination_market_id = reader.text_id("destination_market_id")
		if state.destination_market_id != &"" and content.market(state.destination_market_id) == null:
			reader.fail("destination_market_id", "there is no market \"%s\"" % state.destination_market_id)
	if state.color != &"" and content.color(state.color) == null:
		reader.fail("color", "there is no color \"%s\"" % state.color)
	if state.vehicle != &"" and content.transport_tier(state.vehicle) == null:
		reader.fail("vehicle", "there is no transport tier \"%s\"" % state.vehicle)
	for shipment_reader in reader.objects("shipments"):
		state.shipments.append(ShipmentState.from_snapshot(shipment_reader, now_ms,
			next_shipment_id, shipment_ids))
	state._read_automatic(reader, now_ms)
	state._read_recent_starts(reader, now_ms)
	return state


func _read_automatic(reader: SnapshotReader, now_ms: int) -> void:
	var status := reader.text_id("automatic_status")
	if status != &"":
		if AUTOMATIC_STATUSES.has(status):
			automatic_status = status
		else:
			reader.fail("automatic_status", "must be one of %s, but it is \"%s\"" % [
				", ".join(AUTOMATIC_STATUSES.keys()), status])
	next_automatic_ms = reader.integer("next_automatic_ms")
	if not is_automatic() and next_automatic_ms != 0:
		reader.fail("next_automatic_ms", "must be 0 on a manual link")
	elif is_automatic() and next_automatic_ms < now_ms:
		reader.fail("next_automatic_ms", "must not be before time_ms (%d)" % now_ms)


func _read_recent_starts(reader: SnapshotReader, now_ms: int) -> void:
	var earliest := now_ms - THROUGHPUT_WINDOW_MS + 1
	for start_reader in reader.objects("recent_starts"):
		var started_at_ms := start_reader.integer("started_at_ms", 0)
		var count := start_reader.integer("count", 1)
		if started_at_ms < earliest or started_at_ms > now_ms:
			start_reader.fail("started_at_ms", "must be in the throughput window, from %d to %d" % [
				earliest, now_ms])
		elif not recent_starts.is_empty() and started_at_ms < recent_starts[-1][0]:
			start_reader.fail("started_at_ms", "must not be before the start before it")
		recent_starts.append(PackedInt64Array([started_at_ms, count]))


func to_view(tier: TransportTier, now_ms: int) -> LinkView:
	var view := LinkView.new()
	view.id = id
	view.color = color
	view.source_kind = source_kind
	view.source_factory_id = source_factory_id
	view.source_warehouse_id = source_warehouse_id
	view.destination_kind = destination_kind
	view.destination_market_id = destination_market_id
	view.destination_factory_id = destination_factory_id
	view.destination_warehouse_id = destination_warehouse_id
	view.vehicle = vehicle
	view.transit_time_ms = tier.transit_time_ms
	view.shipment_cost = tier.shipment_cost
	for shipment in shipments:
		view.shipments_in_transit.append(shipment.to_view(now_ms))
	view.automatic = AUTOMATIC_STATUSES[automatic_status]
	view.next_automatic_in_ms = next_automatic_ms - now_ms if is_automatic() else 0
	view.widgets_per_minute = widgets_per_minute(now_ms)
	return view


## The throughput at [param now_ms]: widgets that started on the link in the
## last minute.
func widgets_per_minute(now_ms: int) -> int:
	var count := 0
	for start in recent_starts:
		if start[0] > now_ms - THROUGHPUT_WINDOW_MS:
			count += start[1]
	return count


## Only the source key and the destination key of the link's kinds are in the
## save.
func to_dict() -> Dictionary:
	var data := {
		"id": id,
		"color": color,
		"source_kind": SOURCE_NAMES.find_key(source_kind),
		"destination_kind": DESTINATION_NAMES.find_key(destination_kind),
		"vehicle": vehicle,
		"shipments": shipments.map(func(s: ShipmentState) -> Dictionary: return s.to_dict()),
		"automatic_status": automatic_status,
		"next_automatic_ms": next_automatic_ms,
		"recent_starts": recent_starts.map(func(s: PackedInt64Array) -> Dictionary:
			return {"started_at_ms": s[0], "count": s[1]}),
	}
	if source_kind == LinkView.Source.WAREHOUSE:
		data.source_warehouse_id = source_warehouse_id
	else:
		data.source_factory_id = source_factory_id
	match destination_kind:
		LinkView.Destination.FACTORY:
			data.destination_factory_id = destination_factory_id
		LinkView.Destination.WAREHOUSE:
			data.destination_warehouse_id = destination_warehouse_id
		_:
			data.destination_market_id = destination_market_id
	return data
