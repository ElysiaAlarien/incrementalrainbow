class_name Simulation
extends RefCounted
## The headless simulation core: all game rules, with no scene-tree dependency.
##
## The rest of the game talks to the core only through this interface
## (see ADR-0008):
## [br]- Commands change state and return a [CommandResult]. A command that is
##   not allowed fails with a reason and does not change state.
## [br]- [method tick] advances time by a duration in integer milliseconds.
## [br]- Queries read state. They return copies, never the live state.
## [br][br]
## The same content, seed, commands, and ticks always give the same state.

const FactoryState := preload("res://src/core/state/factory_state.gd")
const LinkState := preload("res://src/core/state/link_state.gd")
const ShipmentState := preload("res://src/core/state/shipment_state.gd")
const DemandState := preload("res://src/core/state/demand_state.gd")
const WarehouseState := preload("res://src/core/state/warehouse_state.gd")
const MarketState := preload("res://src/core/state/market_state.gd")
const ResearchState := preload("res://src/core/state/research_state.gd")
const EventQueue := preload("res://src/core/state/event_queue.gd")

## Kinds of tick events, in the order they happen at one time.
const _EVENT_ARRIVAL := 0
const _EVENT_DEMAND_EVENT_START := 1
const _EVENT_AUTOMATIC_START := 2

## The prestige keep set, in one place (see ADR-0012). A prestige makes a
## fresh run with [method Simulation.new], the same path as a new game, and
## copies only these members into it. Each key is a name for the player, and
## its value lists the members that hold it. All other state, also state that
## a later feature adds, is part of the run and clears by default. To keep new
## state across runs, add it here. The unlocks and bonuses of prestige
## upgrades come from the owned upgrades, so they need no member of their own.
const _PRESTIGE_KEEPS: Dictionary[String, Array] = {
	"Prisms": [&"_prisms"],
	"Prism price": [&"_prisms_bought"],
	"Prestige upgrades and their unlocks": [&"_prestige_upgrades"],
}
## What a prestige clears, as names for the player. A prestige clears all
## state that [constant _PRESTIGE_KEEPS] does not name, so this list only
## tells the player. When a feature adds state to the run, add its name here.
## A test fails for each snapshot key that neither list names.
const _PRESTIGE_CLEARS: PackedStringArray = [
	"Money",
	"Factories",
	"Links, with their vehicles and shipments",
	"Demand and saturation",
	"Community investments and capacity used in each market",
	"Warehouses and the widgets in them",
	"Transport tier",
	"Labs",
	"Research, its progress, and the lab stock",
]

var _content: Content
var _rng: SimRng
var _time_ms: int = 0
var _money: BigNumber
var _next_factory_id: int = 1
var _factories: Array[FactoryState] = []
## The same factories as [member _factories], by id.
var _factories_by_id: Dictionary[int, FactoryState] = {}
var _next_link_id: int = 1
var _links: Array[LinkState] = []
var _next_warehouse_id: int = 1
var _warehouses: Array[WarehouseState] = []
var _next_shipment_id: int = 1
var _demand: DemandState
## Market id to the state of that market, for each market in the content.
var _markets: Dictionary[StringName, MarketState] = {}
## The transport tier the player has. New links use it as their vehicle, and
## it sets which markets are open.
var _transport_tier: TransportTier
## Prisms owned now, and prisms bought across all runs (ADR-0003). Prestige
## clears neither.
var _prisms: int = 0
var _prisms_bought: int = 0
## The ids of the prestige upgrades that the player owns, in content order.
## Prestige does not clear them. Their effects come from this list each time
## (see [method _production_speed] and [method _starting_money]), so that no
## other member must change when the player buys one.
var _prestige_upgrades: Array[StringName] = []
var _next_lab_id: int = 1
## Lab ids, in build order. A lab has no state of its own: the widgets it
## consumes pay for [member _research].
var _labs: Array[int] = []
## All research state of the run. A prestige clears it with the other state of
## the run.
var _research := ResearchState.new()
## Counts what happens during [method progress_offline]. Null at other times.
## It is not state: it does not change what the simulation does.
var _offline_tally: OfflineSummary = null


## [param p_content] must be valid (no [member Content.errors]).
func _init(p_content: Content, p_seed: int) -> void:
	assert(p_content.errors.is_empty(), "Simulation needs valid content: %s" % "; ".join(p_content.errors))
	_content = p_content
	_rng = SimRng.new(p_seed)
	_demand = DemandState.new(_rng.next_u32())
	_demand.schedule_events(0, _rng, _content)
	_money = _starting_money()
	for def in _content.markets():
		_markets[def.id] = MarketState.from_def(def)
	_transport_tier = _content.transport_tiers()[0]


## Makes a simulation from saved state: the inverse of [method snapshot].
## [param reader] records each problem in the state, and the caller must check
## [method SnapshotReader.errors]. Use [method SaveCodec.decode] to load a save.
static func from_snapshot(p_content: Content, reader: SnapshotReader) -> Simulation:
	var sim := Simulation.new(p_content, 0)
	sim._time_ms = reader.integer("time_ms")
	var rng_state := reader.u32_list("rng", 4)
	if rng_state == PackedInt64Array([0, 0, 0, 0]):
		reader.fail("rng", "cannot be all zeros")
	else:
		sim._rng.set_state(rng_state)
	sim._money = reader.big_number("money")
	if sim._money.is_negative():
		reader.fail("money", "cannot be negative")
	sim._next_factory_id = reader.integer("next_factory_id", 1)
	var ids := {}
	var factory_readers: Array[SnapshotReader] = reader.objects("factories")
	for factory_reader in factory_readers:
		var state := FactoryState.from_snapshot(factory_reader, p_content)
		if ids.has(state.id):
			factory_reader.fail("id", "is used by more than one factory")
		elif state.id >= sim._next_factory_id:
			factory_reader.fail("id", "must be less than next_factory_id (%d)" % sim._next_factory_id)
		ids[state.id] = true
		state.synced_ms = sim._time_ms
		sim._factories.append(state)
		sim._factories_by_id[state.id] = state
	sim._read_warehouses(reader)
	sim._read_transport_tier(reader)
	sim._read_labs(reader)
	sim._research = ResearchState.from_snapshot(reader, p_content)
	sim._read_links(reader)
	sim._demand = DemandState.from_snapshot(reader, p_content, sim._time_ms)
	sim._read_markets(reader)
	sim._prisms_bought = reader.integer("prisms_bought", 0)
	sim._prisms = reader.integer("prisms", 0)
	if sim._prisms > sim._prisms_bought:
		reader.fail("prisms", "cannot be more than prisms_bought (%d)" % sim._prisms_bought)
	sim._read_prestige_upgrades(reader)
	sim._check_input_bay_space(factory_readers)
	sim._check_warehouse_space(reader)
	return sim


## Reads the owned prestige upgrades for [method from_snapshot], and keeps
## them in content order.
func _read_prestige_upgrades(reader: SnapshotReader) -> void:
	var owned := {}
	for id in reader.text_id_list("prestige_upgrades"):
		if _content.prestige_upgrade(id) == null:
			reader.fail("prestige_upgrades", "there is no prestige upgrade \"%s\"" % id)
		elif owned.has(id):
			reader.fail("prestige_upgrades", "%s is in the list more than once" % id)
		owned[id] = true
	_set_prestige_upgrades(owned)


## Sets the owned prestige upgrades to the ids in [param owned], in content
## order. Ids that are not in the content are not kept.
func _set_prestige_upgrades(owned: Dictionary) -> void:
	_prestige_upgrades.clear()
	for def in _content.prestige_upgrades():
		if owned.has(def.id):
			_prestige_upgrades.append(def.id)


## Reads the warehouses for [method from_snapshot].
func _read_warehouses(reader: SnapshotReader) -> void:
	_next_warehouse_id = reader.integer("next_warehouse_id", 1)
	var ids := {}
	for warehouse_reader in reader.objects("warehouses"):
		var state := WarehouseState.from_snapshot(warehouse_reader, _content)
		if ids.has(state.id):
			warehouse_reader.fail("id", "is used by more than one warehouse")
		elif state.id >= _next_warehouse_id:
			warehouse_reader.fail("id", "must be less than next_warehouse_id (%d)" % _next_warehouse_id)
		ids[state.id] = true
		_warehouses.append(state)


## Checks for [method from_snapshot] that no warehouse can overflow: the
## widgets in it and on their way to it fit in its space.
func _check_warehouse_space(reader: SnapshotReader) -> void:
	var space := _content.warehouse_balance.space
	for i in _warehouses.size():
		var state := _warehouses[i]
		var total := state.count + _widgets_in_transit_to_warehouse(state.id)
		if total > space:
			reader.fail("warehouses[%d].count" % i,
				"%d widgets are in the warehouse and on the way, but it holds %d" % [total, space])


## Reads the lab ids for [method from_snapshot].
func _read_labs(reader: SnapshotReader) -> void:
	_next_lab_id = reader.integer("next_lab_id", 1)
	for lab_reader in reader.objects("labs"):
		var id := lab_reader.integer("id", 1)
		if _labs.has(id):
			lab_reader.fail("id", "is used by more than one lab")
		elif id >= _next_lab_id:
			lab_reader.fail("id", "must be less than next_lab_id (%d)" % _next_lab_id)
		_labs.append(id)


## Reads the transport tier for [method from_snapshot].
func _read_transport_tier(reader: SnapshotReader) -> void:
	var id := reader.text_id("transport_tier")
	var tier := _content.transport_tier(id)
	if tier != null:
		_transport_tier = tier
	elif id != &"":
		reader.fail("transport_tier", "there is no transport tier \"%s\"" % id)


## Reads the links and their shipments for [method from_snapshot], and checks
## them against the factories, the warehouses, the labs, the time, and the
## transport tier, which it has read first.
func _read_links(reader: SnapshotReader) -> void:
	_next_link_id = reader.integer("next_link_id", 1)
	_next_shipment_id = reader.integer("next_shipment_id", 1)
	var link_ids := {}
	var shipment_ids := {}
	var routes := {}
	var link_readers: Array[SnapshotReader] = reader.objects("links")
	for link_reader in link_readers:
		var state := LinkState.from_snapshot(link_reader, _content, _time_ms,
			_next_shipment_id, shipment_ids)
		if link_ids.has(state.id):
			link_reader.fail("id", "is used by more than one link")
		elif state.id >= _next_link_id:
			link_reader.fail("id", "must be less than next_link_id (%d)" % _next_link_id)
		link_ids[state.id] = true
		var vehicle := _content.transport_tier(state.vehicle)
		if vehicle != null and vehicle.rank > _transport_tier.rank:
			link_reader.fail("vehicle", "%s is a higher tier than the transport tier (%s)" % [
				vehicle.id, _transport_tier.id])
		var source_text := _check_link_source(state, link_reader)
		var destination_key := "destination_market_id"
		var destination_text := String(state.destination_market_id)
		match state.destination_kind:
			LinkView.Destination.FACTORY:
				destination_key = "destination_factory_id"
				destination_text = "factory #%d" % state.destination_factory_id
				var target := _factory_state(state.destination_factory_id)
				if target == null:
					link_reader.fail(destination_key, "there is no factory #%d" % state.destination_factory_id)
				elif not target.uses_input(state.color):
					link_reader.fail(destination_key, "the recipe of factory #%d (%s) does not use %s" % [
						target.id, target.color, state.color])
			LinkView.Destination.WAREHOUSE:
				destination_key = "destination_warehouse_id"
				destination_text = "warehouse #%d" % state.destination_warehouse_id
				var target := _warehouse_state(state.destination_warehouse_id)
				if target == null:
					link_reader.fail(destination_key, "there is no warehouse #%d" % state.destination_warehouse_id)
				elif target.color != state.color:
					link_reader.fail(destination_key, "warehouse #%d holds %s, not %s" % [
						target.id, target.color, state.color])
				elif state.source_kind == LinkView.Source.WAREHOUSE:
					link_reader.fail(destination_key, "a link cannot go from a warehouse to a warehouse")
			LinkView.Destination.LAB:
				destination_key = "destination_lab_id"
				destination_text = "lab #%d" % state.destination_lab_id
				if not _labs.has(state.destination_lab_id):
					link_reader.fail(destination_key, "there is no lab #%d" % state.destination_lab_id)
		var ends := [state.source_key(), state.destination_key()]
		if routes.has(ends):
			link_reader.fail(destination_key, "%s has more than one link to %s" % [source_text, destination_text])
		routes[ends] = true
		_links.append(state)
	_check_splits(link_readers)


## Checks for [method from_snapshot] that the links of each source agree on
## its split: all of them have a percentage or none do, and the percentages
## add up to 100. [param readers] read the links, in the same order.
func _check_splits(readers: Array[SnapshotReader]) -> void:
	var checked := {}
	for i in _links.size():
		if checked.has(_links[i]):
			continue
		var group := _split_group(_links[i])
		var with_split := group.filter(func(l: LinkState) -> bool: return l.has_split()).size()
		var total := 0
		for state in group:
			checked[state] = true
			total += maxi(state.split_percent, 0)
		if with_split != 0 and with_split != group.size():
			readers[i].fail("split_percent", "the links from this source must all have a split percentage, or none")
		elif with_split != 0 and total != 100:
			readers[i].fail("split_percent", "the split percentages of the links from this source add up to %d, not 100" % total)


## Reads the markets for [method from_snapshot]. A market that the save does
## not have, such as one that is new in the content, starts as at the start of
## a run. The widgets on their way to a market are not checked against its
## capacity, because a save from before capacity (version 7) can have more on
## the way. Capacity left is never less than 0, so the market accepts no more
## until they arrive.
func _read_markets(reader: SnapshotReader) -> void:
	var seen := {}
	for market_reader in reader.objects("markets"):
		var state := MarketState.from_snapshot(market_reader, _time_ms, _content.market_balance)
		if state.id == &"":
			continue
		if _content.market(state.id) == null:
			market_reader.fail("id", "there is no market \"%s\"" % state.id)
		elif seen.has(state.id):
			market_reader.fail("id", "market %s is in the save more than once" % state.id)
		else:
			seen[state.id] = true
			_markets[state.id] = state


## Checks for [method _read_links] that the source of [param state] exists and
## has the link's color. Returns its name for messages, such as "factory #2".
func _check_link_source(state: LinkState, reader: SnapshotReader) -> String:
	if state.source_kind == LinkView.Source.WAREHOUSE:
		var warehouse := _warehouse_state(state.source_warehouse_id)
		if warehouse == null:
			reader.fail("source_warehouse_id", "there is no warehouse #%d" % state.source_warehouse_id)
		elif warehouse.color != state.color:
			reader.fail("color", "must be the color of warehouse #%d (%s)" % [warehouse.id, warehouse.color])
		return "warehouse #%d" % state.source_warehouse_id
	var source := _factory_state(state.source_factory_id)
	if source == null:
		reader.fail("source_factory_id", "there is no factory #%d" % state.source_factory_id)
	elif source.color != state.color:
		reader.fail("color", "must be the color of factory #%d (%s)" % [source.id, source.color])
	return "factory #%d" % state.source_factory_id


## Checks for [method from_snapshot] that no input bay can overflow: the
## widgets in each bay and on their way to it fit in the bay. [param readers]
## read the factories, in the same order.
func _check_input_bay_space(readers: Array[SnapshotReader]) -> void:
	var capacity := _content.factory_balance.input_bay_capacity
	for i in _factories.size():
		var state := _factories[i]
		for input in state.input_bays:
			var total := state.input_bays[input] + _widgets_in_transit_to(state.id, input)
			if total > capacity:
				readers[i].fail("input_bays", "%d %s widgets are in the bay and on the way, but the bay holds %d" % [
					total, input, capacity])


# --- Commands -----------------------------------------------------------------

## Builds a factory of [param color] for [method factory_build_cost]. A factory
## of a color with a recipe is a mixed factory, with one empty input bay for
## each input color. On success, [member CommandResult.value] is the new
## factory id.
func build_factory(color: StringName) -> CommandResult:
	var color_def := _content.color(color)
	if color_def == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_COLOR,
			"There is no color \"%s\"." % color)
	if not is_color_unlocked(color):
		return CommandResult.failure(CommandResult.Reason.COLOR_LOCKED,
			"%s needs %s first: %s." % [color_def.name,
				"a prestige upgrade" if color_def.unlock == ColorDef.Unlock.PRESTIGE_UPGRADE else "research",
				" or ".join(_content.unlocker_names(color_def))])
	var cost := factory_build_cost()
	if _money.is_less_than(cost):
		return _not_enough_money("A factory", cost)

	_money = _money.sub(cost)
	var state := FactoryState.new(_next_factory_id, color, color_def.recipe)
	_next_factory_id += 1
	state.synced_ms = _time_ms
	_factories.append(state)
	_factories_by_id[state.id] = state
	return CommandResult.success(state.id)


## Adds one production line to the factory with [param factory_id], for money.
## On success, [member CommandResult.value] is the new size of the factory.
func add_production_line(factory_id: int) -> CommandResult:
	var state := _factory_state(factory_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_FACTORY,
			"There is no factory #%d." % factory_id)
	var cost := _content.factory_balance.next_line_cost(state.size)
	if _money.is_less_than(cost):
		return _not_enough_money("A new production line", cost)

	_money = _money.sub(cost)
	state.size += 1
	return CommandResult.success(state.size)


## Makes a link from the factory [param factory_id] to the market
## [param market_id], which must be open: the transport tier must reach its
## remoteness. The link carries the factory's color, and its vehicle is the
## transport tier the player has now. Making a link is free; each shipment
## costs money. On success, [member CommandResult.value] is the new link id.
func make_link(factory_id: int, market_id: StringName) -> CommandResult:
	var source := _factory_state(factory_id)
	if source == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_FACTORY,
			"There is no factory #%d." % factory_id)
	var market := _content.market(market_id)
	if market == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_MARKET,
			"There is no market \"%s\"." % market_id)
	if not _transport_tier.reaches(market.remoteness):
		return _too_remote(market)
	if has_link(factory_id, market_id):
		return CommandResult.failure(CommandResult.Reason.LINK_EXISTS,
			"Factory #%d already has a link to %s." % [factory_id, market.name])

	return _add_link(LinkState.to_market(_next_link_id, source.color, factory_id, market_id,
		_transport_tier.id))


## Makes a link from the factory [param source_id] to the mixed factory
## [param destination_id], whose recipe must use the source's color. The link
## carries that color to the input bay of that color. Like a link to a market,
## its vehicle is the transport tier the player has now and it is free.
## Factories have no remoteness, so every tier reaches them. On success,
## [member CommandResult.value] is the new link id.
func make_factory_link(source_id: int, destination_id: int) -> CommandResult:
	var source := _factory_state(source_id)
	if source == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_FACTORY,
			"There is no factory #%d." % source_id)
	var destination := _factory_state(destination_id)
	if destination == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_FACTORY,
			"There is no factory #%d." % destination_id)
	if not destination.uses_input(source.color):
		return CommandResult.failure(CommandResult.Reason.NOT_A_RECIPE_INPUT,
			"%s does not use %s." % [_factory_name(destination), _content.color(source.color).name.to_lower()])
	if has_factory_link(source_id, destination_id):
		return CommandResult.failure(CommandResult.Reason.LINK_EXISTS,
			"Factory #%d already has a link to factory #%d." % [source_id, destination_id])

	return _add_link(LinkState.to_factory(_next_link_id, source.color, source_id, destination_id,
		_transport_tier.id))


## Builds a warehouse for [param color] for [method warehouse_build_cost], when
## [method is_warehouse_unlocked]. A new warehouse is empty. On success,
## [member CommandResult.value] is the new warehouse id.
func build_warehouse(color: StringName) -> CommandResult:
	var color_def := _content.color(color)
	if color_def == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_COLOR,
			"There is no color \"%s\"." % color)
	if not is_warehouse_unlocked():
		return CommandResult.failure(CommandResult.Reason.WAREHOUSE_LOCKED,
			"Warehouses unlock when you have %d factories." % _content.warehouse_balance.unlock_factory_count)
	var cost := warehouse_build_cost()
	if _money.is_less_than(cost):
		return _not_enough_money("A warehouse", cost)

	_money = _money.sub(cost)
	var state := WarehouseState.new(_next_warehouse_id, color)
	_next_warehouse_id += 1
	_warehouses.append(state)
	return CommandResult.success(state.id)


## Makes a link from the factory [param factory_id] to the warehouse
## [param warehouse_id], which must hold the factory's color. Like other links,
## its vehicle is the transport tier the player has now and it is free. On success,
## [member CommandResult.value] is the new link id.
func link_factory_to_warehouse(factory_id: int, warehouse_id: int) -> CommandResult:
	var source := _factory_state(factory_id)
	if source == null:
		return _unknown_factory(factory_id)
	var destination := _warehouse_state(warehouse_id)
	if destination == null:
		return _unknown_warehouse(warehouse_id)
	if destination.color != source.color:
		return CommandResult.failure(CommandResult.Reason.WRONG_COLOR,
			"%s holds %s, but %s makes %s." % [_warehouse_name(destination),
				_color_text(destination.color), _factory_name(source), _color_text(source.color)])
	return _add_new_link(LinkState.to_warehouse(_next_link_id, source.color, factory_id, warehouse_id,
		_transport_tier.id))


## Makes a link from the warehouse [param warehouse_id] to the market
## [param market_id], which must be open, as for [method make_link]. The link
## carries the warehouse's color. On success, [member CommandResult.value] is
## the new link id.
func link_warehouse_to_market(warehouse_id: int, market_id: StringName) -> CommandResult:
	var source := _warehouse_state(warehouse_id)
	if source == null:
		return _unknown_warehouse(warehouse_id)
	var market := _content.market(market_id)
	if market == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_MARKET,
			"There is no market \"%s\"." % market_id)
	if not _transport_tier.reaches(market.remoteness):
		return _too_remote(market)
	return _add_new_link(LinkState.to_market(_next_link_id, source.color, 0, market_id,
		_transport_tier.id).from_warehouse(warehouse_id))


## Makes a link from the warehouse [param warehouse_id] to the mixed factory
## [param factory_id], whose recipe must use the warehouse's color. On
## success, [member CommandResult.value] is the new link id.
func link_warehouse_to_factory(warehouse_id: int, factory_id: int) -> CommandResult:
	var source := _warehouse_state(warehouse_id)
	if source == null:
		return _unknown_warehouse(warehouse_id)
	var destination := _factory_state(factory_id)
	if destination == null:
		return _unknown_factory(factory_id)
	if not destination.uses_input(source.color):
		return CommandResult.failure(CommandResult.Reason.NOT_A_RECIPE_INPUT,
			"%s does not use %s." % [_factory_name(destination), _color_text(source.color)])
	return _add_new_link(LinkState.to_factory(_next_link_id, source.color, 0, factory_id,
		_transport_tier.id).from_warehouse(warehouse_id))


## Builds a lab for [method lab_build_cost]. Links bring widgets to it, and
## it consumes them to pay for the selected research. On success,
## [member CommandResult.value] is the new lab id.
func build_lab() -> CommandResult:
	var cost := lab_build_cost()
	if _money.is_less_than(cost):
		return _not_enough_money("A lab", cost)

	_money = _money.sub(cost)
	_labs.append(_next_lab_id)
	_next_lab_id += 1
	return CommandResult.success(_labs[-1])


## Makes a link from the factory [param source_id] to the lab
## [param lab_id]. The link carries the factory's color. Like other links, its
## vehicle is the transport tier the player has now and it is free. Labs have
## no remoteness, so every tier reaches them. A shipment carries only what the
## selected research still needs (see [method _accepted_count]). On success,
## [member CommandResult.value] is the new link id.
func make_lab_link(source_id: int, lab_id: int) -> CommandResult:
	var source := _factory_state(source_id)
	if source == null:
		return _unknown_factory(source_id)
	if not _labs.has(lab_id):
		return _unknown_lab(lab_id)
	return _add_new_link(LinkState.to_lab(_next_link_id, source.color, source_id, lab_id,
		_transport_tier.id))


## Makes a link from the warehouse [param warehouse_id] to the lab
## [param lab_id], as for [method make_lab_link]. The link carries the
## warehouse's color. On success, [member CommandResult.value] is the new link
## id.
func link_warehouse_to_lab(warehouse_id: int, lab_id: int) -> CommandResult:
	var source := _warehouse_state(warehouse_id)
	if source == null:
		return _unknown_warehouse(warehouse_id)
	if not _labs.has(lab_id):
		return _unknown_lab(lab_id)
	return _add_new_link(LinkState.to_lab(_next_link_id, source.color, 0, lab_id,
		_transport_tier.id).from_warehouse(warehouse_id))


## Selects the research [param research_id], so that labs consume widgets to
## pay for it. Research keeps what was paid for it when the player selects
## other research. Widgets in the lab stock pay for it at once, which can
## complete it. When research is complete, its unlocks are available and
## nothing is selected.
func select_research(research_id: StringName) -> CommandResult:
	var def := _content.research_def(research_id)
	if def == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_RESEARCH,
			"There is no research \"%s\"." % research_id)
	if _research.is_complete(research_id):
		return CommandResult.failure(CommandResult.Reason.RESEARCH_COMPLETE,
			"%s is complete already." % def.name)
	if not _research.has_requirements(def):
		var missing: Array[StringName] = []
		for id in def.requires:
			if not _research.is_complete(id):
				missing.append(id)
		return CommandResult.failure(CommandResult.Reason.RESEARCH_LOCKED,
			"%s needs research first: %s." % [def.name, ", ".join(_content.research_names(missing))])

	_research.select(research_id, _content)
	return CommandResult.success()


## Adds [param state] if no link has the same source and destination yet.
func _add_new_link(state: LinkState) -> CommandResult:
	for other in _links:
		if other.source_key() == state.source_key() and other.destination_key() == state.destination_key():
			return CommandResult.failure(CommandResult.Reason.LINK_EXISTS,
				"%s already has a link to %s." % [_source_name(state), _destination_name(state)])
	return _add_link(state)


func _unknown_factory(id: int) -> CommandResult:
	return CommandResult.failure(CommandResult.Reason.UNKNOWN_FACTORY, "There is no factory #%d." % id)


func _too_remote(market: MarketDef) -> CommandResult:
	return CommandResult.failure(CommandResult.Reason.MARKET_TOO_REMOTE,
		"%s is too remote for %s: it needs %s." % [market.name, _transport_tier.plural_name.to_lower(),
			_content.tier_for_remoteness(market.remoteness).plural_name.to_lower()])


func _unknown_lab(id: int) -> CommandResult:
	return CommandResult.failure(CommandResult.Reason.UNKNOWN_LAB, "There is no lab #%d." % id)


func _unknown_warehouse(id: int) -> CommandResult:
	return CommandResult.failure(CommandResult.Reason.UNKNOWN_WAREHOUSE, "There is no warehouse #%d." % id)


## Adds [param state]. If its source has a split, the new link gets 0% of it.
func _add_link(state: LinkState) -> CommandResult:
	for other in _split_group(state):
		if other.has_split():
			state.split_percent = 0
			break
	_next_link_id += 1
	_links.append(state)
	return CommandResult.success(state.id)


## Starts a shipment on the link [param link_id] by hand. It costs the
## vehicle's shipment cost now and arrives after the vehicle's transit time. At
## a market, the market sells it. At a mixed factory, it goes into the input
## bay of its color. At a warehouse, it goes into the warehouse. It carries the
## widgets in the source (a factory's output bay or a warehouse), up to what
## the destination accepts now (see [method _accepted_count]). A shipment
## by hand is outside the split of its source: it can take any widgets there,
## and they do not count in the split. On success,
## [member CommandResult.value] is the widget count.
func start_shipment(link_id: int) -> CommandResult:
	var state := _link_state(link_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_LINK,
			"There is no link #%d." % link_id)
	return _start_shipment(state, false)


## Buys automatic transport for the link [param link_id], for
## [method automatic_transport_cost]. From now on, the link starts a shipment
## by itself: first now, and after that once each transit time of its vehicle, by the rules
## of [method start_shipment]. A start with nothing to ship or too little money
## sends nothing, and [member LinkView.automatic] shows why.
func buy_automatic_transport(link_id: int) -> CommandResult:
	var state := _link_state(link_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_LINK,
			"There is no link #%d." % link_id)
	if state.is_automatic():
		return CommandResult.failure(CommandResult.Reason.ALREADY_AUTOMATIC,
			"Link #%d already has automatic transport." % link_id)
	var cost := automatic_transport_cost()
	if _money.is_less_than(cost):
		return _not_enough_money("Automatic transport", cost)

	_money = _money.sub(cost)
	state.make_automatic(_time_ms)
	return CommandResult.success()


## Buys the next transport tier for its price. Current links keep their
## vehicles (see [method upgrade_vehicle]). New links use the new tier, and the
## markets that it reaches open. On success, [member CommandResult.value] is
## the id of the new tier.
func buy_transport_tier() -> CommandResult:
	var tier := next_transport_tier()
	if tier == null:
		return CommandResult.failure(CommandResult.Reason.NO_HIGHER_TIER,
			"You already have the highest transport tier (%s)." % _transport_tier.name.to_lower())
	if _money.is_less_than(tier.price):
		return _not_enough_money("The %s tier" % tier.name.to_lower(), tier.price)

	_money = _money.sub(tier.price)
	_transport_tier = tier
	return CommandResult.success(tier.id)


## Moves the vehicle of the link [param link_id] onto the transport tier the
## player has now, for that tier's vehicle upgrade cost. From then on, each
## new shipment on the link costs the new vehicle's shipment cost and takes
## its transit time. Shipments in transit keep their arrival time. On an
## automatic link, the next automatic start keeps its time, and the starts
## after it come once each new transit time. On success,
## [member CommandResult.value] is the id of the new vehicle.
func upgrade_vehicle(link_id: int) -> CommandResult:
	var state := _link_state(link_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_LINK,
			"There is no link #%d." % link_id)
	if state.vehicle == _transport_tier.id:
		return CommandResult.failure(CommandResult.Reason.VEHICLE_IS_CURRENT,
			"Link #%d already uses %s, your transport tier." % [link_id, _transport_tier.plural_name.to_lower()])
	var cost := _transport_tier.vehicle_upgrade_cost
	if _money.is_less_than(cost):
		return _not_enough_money("A %s for link #%d" % [_transport_tier.name.to_lower(), link_id], cost)

	_money = _money.sub(cost)
	state.vehicle = _transport_tier.id
	return CommandResult.success(state.vehicle)


## Sets the split of one source: [param shares] maps link ids to whole
## percentages from 0 to 100, which add up to 100. Each link must have
## automatic transport, and all must start at one source with one color. The
## other links from that source, and links made from it later, get 0%. From
## now on, each automatic start ships only up to its link's percentage of the
## source's widgets (see [method _split_allowance]), and a new split counts
## from 0. A shipment by hand is outside the split.
func set_split(shares: Dictionary) -> CommandResult:
	var first: LinkState = null
	var total := 0
	for key: Variant in shares:
		var state: LinkState = _link_state(key) if key is int else null
		if state == null:
			return CommandResult.failure(CommandResult.Reason.UNKNOWN_LINK,
				"There is no link %s." % ("#%d" % key if key is int else "\"%s\"" % key))
		var percent: Variant = shares[key]
		if not percent is int or percent < 0 or percent > 100:
			return CommandResult.failure(CommandResult.Reason.BAD_PERCENT,
				"A percentage must be a whole number from 0 to 100, but link #%d has %s." % [key, percent])
		if not state.is_automatic():
			return CommandResult.failure(CommandResult.Reason.NOT_AUTOMATIC,
				"Link #%d has manual transport. A split is only across automatic links." % key)
		if first == null:
			first = state
		elif not first.same_source_as(state):
			return CommandResult.failure(CommandResult.Reason.MIXED_SOURCES,
				"Link #%d does not start at %s. A split is across the links of one color from one source." % [
					key, _source_name(first)])
		total += percent
	if total != 100:
		return CommandResult.failure(CommandResult.Reason.SPLIT_NOT_100,
			"The percentages of a split must add up to 100, but these add up to %d." % total)

	for state in _split_group(first):
		state.set_split(shares.get(state.id, 0))
	return CommandResult.success()


## Removes the split of the source of the link [param link_id]. Then each link
## from that source ships what it can, as before the split.
func clear_split(link_id: int) -> CommandResult:
	var state := _link_state(link_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_LINK,
			"There is no link #%d." % link_id)
	if not state.has_split():
		return CommandResult.failure(CommandResult.Reason.NO_SPLIT,
			"%s has no split." % _source_name(state))

	for other in _split_group(state):
		other.set_split(LinkView.NO_SPLIT)
	return CommandResult.success()


## Sets the sell threshold of the warehouse [param warehouse_id] to
## [param percent], a whole percent of normal demand of at least 1 (100 is
## normal demand; see [method MarketView.demand_percent]). From now on, while the demand
## for the warehouse's color in a market is below the threshold, the automatic
## starts of the links from the warehouse to that market send nothing. When
## demand goes up to the threshold or above, the next automatic start sends
## widgets again. Links to factories and labs do not hold, and a shipment by
## hand is outside the hold (ADR-0016).
func set_sell_threshold(warehouse_id: int, percent: int) -> CommandResult:
	var state := _warehouse_state(warehouse_id)
	if state == null:
		return _unknown_warehouse(warehouse_id)
	if percent < 1:
		return CommandResult.failure(CommandResult.Reason.BAD_SELL_THRESHOLD,
			"A sell threshold must be a whole percentage of at least 1%%, but it is %d%%." % percent)

	state.sell_threshold = percent
	return CommandResult.success()


## Removes the sell threshold of the warehouse [param warehouse_id]. Then its
## links send at any demand.
func clear_sell_threshold(warehouse_id: int) -> CommandResult:
	var state := _warehouse_state(warehouse_id)
	if state == null:
		return _unknown_warehouse(warehouse_id)
	if state.sell_threshold == WarehouseView.NO_SELL_THRESHOLD:
		return CommandResult.failure(CommandResult.Reason.NO_SELL_THRESHOLD,
			"%s has no sell threshold." % _warehouse_name(state))

	state.sell_threshold = WarehouseView.NO_SELL_THRESHOLD
	return CommandResult.success()


## Starts a shipment on [param state] if the rules allow it, for
## [method start_shipment] and, when [param automatic] is true, for automatic
## starts. Only automatic starts follow the split and the sell threshold. A
## held start ships nothing, so a held link of a split keeps its share
## (ADR-0013). The failure of an
## automatic start has no message, because no one sees it and a message costs
## time in offline progress.
func _start_shipment(state: LinkState, automatic: bool) -> CommandResult:
	if automatic and _is_held(state):
		return CommandResult.failure(CommandResult.Reason.HELD, "")
	var available := _source_count(state)
	var allowed := _split_allowance(state, available) if automatic else available
	var count := _accepted_count(state, allowed)
	if count <= 0:
		if automatic:
			return CommandResult.failure(CommandResult.Reason.NOTHING_TO_SHIP, "")
		var why := _accepts_nothing_text(state)
		if available <= 0:
			why = "%s has no widgets." % _source_name(state)
		elif allowed <= 0:
			why = _split_used_text(state)
		return CommandResult.failure(CommandResult.Reason.NOTHING_TO_SHIP,
			"Nothing to ship: %s" % why)
	var tier := _content.transport_tier(state.vehicle)
	if _money.is_less_than(tier.shipment_cost):
		if automatic:
			return CommandResult.failure(CommandResult.Reason.NOT_ENOUGH_MONEY, "")
		return _not_enough_money("A shipment by %s" % tier.name.to_lower(), tier.shipment_cost)

	_money = _money.sub(tier.shipment_cost)
	if state.source_kind == LinkView.Source.WAREHOUSE:
		_warehouse_state(state.source_warehouse_id).take(count)
	else:
		_factory_state(state.source_factory_id).take_output(count)
	if automatic:
		state.record_split_shipment(count)
	state.add_shipment(_next_shipment_id, count, _time_ms, tier.transit_time_ms)
	_next_shipment_id += 1
	return CommandResult.success(count)


## Buys one prism for [method prisms] [code].next_price[/code]. On success,
## [member CommandResult.value] is the number of prisms owned.
func buy_prism() -> CommandResult:
	var price := _prism_price()
	if _money.is_less_than(price):
		return _not_enough_money("A prism", price)

	_money = _money.sub(price)
	_prisms += 1
	_prisms_bought += 1
	return CommandResult.success(_prisms)


## Ends this run and starts a fresh one. A prestige keeps only the set in
## [constant _PRESTIGE_KEEPS] (see [method prestige_preview]) and clears all
## else to the state of a new game. The player must own at least one prism.
## The random number generator of the old run seeds the new run, so the same
## commands and ticks give the same new run.
func prestige() -> CommandResult:
	var blocked := _prestige_blocked()
	if blocked != null:
		return blocked

	var kept := {}
	for members: Array in _PRESTIGE_KEEPS.values():
		for member: StringName in members:
			kept[member] = true
	var fresh := Simulation.new(_content, (_rng.next_u32() << 32) | _rng.next_u32())
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not kept.has(StringName(property.name)):
			set(property.name, fresh.get(property.name))
	# A new game has no prestige upgrades, so the fresh run has the starting
	# money of the content. The kept upgrades add their bonus to it.
	_money = _starting_money()
	return CommandResult.success()


## Buys the prestige upgrade [param upgrade_id] for its price in prisms. It
## has its effect at once, and in all later runs: a prestige keeps it. A
## bonus to production speed applies to all factories from now on, and a
## bonus to starting money adds that money now, as at the start of a run. On
## success, [member CommandResult.value] is the prisms that the player has
## left.
func buy_prestige_upgrade(upgrade_id: StringName) -> CommandResult:
	var def := _content.prestige_upgrade(upgrade_id)
	if def == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_PRESTIGE_UPGRADE,
			"There is no prestige upgrade \"%s\"." % upgrade_id)
	if _prestige_upgrades.has(upgrade_id):
		return CommandResult.failure(CommandResult.Reason.PRESTIGE_UPGRADE_OWNED,
			"You own %s already." % def.name)
	if _prisms < def.price:
		return CommandResult.failure(CommandResult.Reason.NOT_ENOUGH_PRISMS,
			"%s costs %s, but you have only %s." % [def.name, _prism_count_text(def.price),
				_prism_count_text(_prisms)])

	# Commands come between ticks, so each factory has made its widgets up to
	# now at the old speed. From now on, it makes them at the new speed.
	_prisms -= def.price
	var owned := {}
	for id in _prestige_upgrades:
		owned[id] = true
	owned[upgrade_id] = true
	_set_prestige_upgrades(owned)
	_money = _money.add(def.starting_money)
	return CommandResult.success(_prisms)


## Such as "1 prism" or "3 prisms".
static func _prism_count_text(count: int) -> String:
	return "%d %s" % [count, "prism" if count == 1 else "prisms"]


## A failure if [method prestige] is not allowed now, or null.
func _prestige_blocked() -> CommandResult:
	if _prisms <= 0:
		return CommandResult.failure(CommandResult.Reason.NO_PRISMS,
			"A prestige needs at least one prism. Buy a prism first.")
	return null


## Makes a community investment in the market [param market_id] for
## [param goal]: it grows the population, which gives more capacity, or the
## income, which gives higher prices. It costs
## [method MarketView.investment_cost]. On success,
## [member CommandResult.value] is the new population or income.
func make_community_investment(market_id: StringName, goal: MarketView.Investment) -> CommandResult:
	assert(MarketView.Investment.values().has(goal), "unknown investment goal %d" % goal)
	var state: MarketState = _markets.get(market_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_MARKET,
			"There is no market \"%s\"." % market_id)
	var cost := _investment_cost(state, goal)
	if _money.is_less_than(cost):
		var what := "population" if goal == MarketView.Investment.POPULATION else "income"
		return _not_enough_money("A community investment for %s in %s" % [what,
			_content.market(market_id).name], cost)

	_money = _money.sub(cost)
	state.invest(goal, _content.market_balance)
	return CommandResult.success(state.population if goal == MarketView.Investment.POPULATION else state.income)


## Why the destination of [param state] accepts no widgets now.
func _accepts_nothing_text(state: LinkState) -> String:
	if state.destination_kind == LinkView.Destination.FACTORY:
		var destination := _factory_state(state.destination_factory_id)
		return "the %s input bay of %s is full, with the widgets on the way." % [
			_color_text(state.color), _factory_name(destination)]
	if state.destination_kind == LinkView.Destination.WAREHOUSE:
		return "%s is full, with the widgets on the way." % _warehouse_name(
			_warehouse_state(state.destination_warehouse_id))
	if state.destination_kind == LinkView.Destination.LAB:
		if _research.selected == &"":
			return "lab #%d has no research selected." % state.destination_lab_id
		return "%s needs no more %s, with the widgets on the way and in the lab stock." % [
			_content.research_def(_research.selected).name, _color_text(state.color)]
	var market := _content.market(state.destination_market_id)
	return "%s has no capacity left in this period, with the widgets on the way. Its capacity is %d widgets in each period." % [
		market.name, _markets[market.id].capacity(_content.market_balance)]


## Why the split lets [param state] ship nothing now.
func _split_used_text(state: LinkState) -> String:
	if state.split_percent == 0:
		return "the split of %s sends 0%% to link #%d." % [_source_name(state), state.id]
	return "link #%d has its %d%% of the split of %s now." % [state.id, state.split_percent, _source_name(state)]


func _not_enough_money(what: String, cost: BigNumber) -> CommandResult:
	return CommandResult.failure(CommandResult.Reason.NOT_ENOUGH_MONEY,
		"%s costs %s, but you have only %s." % [what, cost.format(), _money.format()])


# --- Time ---------------------------------------------------------------------

## Advances the simulation by [param duration_ms] milliseconds. Time is an
## integer so that one long tick gives the same state as many short ticks.
##
## Inside the tick, events happen one at a time in time order, and factories
## make widgets up to each event that uses them. The events are shipment
## arrivals, which sell or go into an input bay, a warehouse, or a lab, demand
## event starts, and automatic starts. At one time, arrivals happen first, in
## start order, so their money and widgets can serve automatic starts at that
## time, and they sell at the demand from before a demand event that starts at
## that time. Then demand events start, then automatic shipments, in link
## order. A tick that ends at a time does the arrivals at that time, and the
## next tick does the starts at that time, so that ticks of any length give the
## same state. BigNumber sums are float sums, so this order sets the money
## (ADR-0008).
##
## A tick takes time in proportion to the size of the state, plus a small
## time for each event. To add a kind of event, add an [code]_EVENT_[/code]
## constant in its place in the order, push its events in
## [method _events_until] and from its handler, and handle it in the match
## below.
func tick(duration_ms: int) -> void:
	assert(duration_ms >= 0, "tick duration cannot be negative")
	if duration_ms <= 0:
		return
	var end_ms := _time_ms + duration_ms
	# A save from before demand events has no next start yet.
	_demand.schedule_events(_time_ms, _rng, _content)
	var events := _events_until(end_ms)
	while not events.is_empty():
		var event := events.pop()
		_time_ms = event[0]
		match event[1]:
			_EVENT_ARRIVAL:
				_deliver(event[3], event[4])
			_EVENT_DEMAND_EVENT_START:
				_demand.start_due_events(_time_ms, _rng, _content)
				_push_demand_event_start(events, end_ms)
			_EVENT_AUTOMATIC_START:
				_start_automatic_shipment(event[3], event[2], events, end_ms)
	_time_ms = end_ms
	for state in _factories:
		_sync(state)
	for state in _links:
		state.forget_old_starts(_time_ms)
	_demand.prune(_time_ms)
	for state: MarketState in _markets.values():
		state.forget_old_periods(_time_ms, _content.market_balance)


## The time of offline progress for [param time_away_ms] (see
## [method LoadResult.time_away_ms]): the time away, up to
## [member Content.max_offline_ms]. Time away above it gives no progress.
func offline_progress_ms(time_away_ms: int) -> int:
	return clampi(time_away_ms, 0, _content.max_offline_ms)


## The most time away that offline progress applies.
func max_offline_ms() -> int:
	return _content.max_offline_ms


## Applies offline progress for [param duration_ms], which
## [method offline_progress_ms] gives for the time that the player was away.
## It is a normal [method tick], with no other rule. Manual transport is off
## by its nature, because only the [method start_shipment] command starts a
## manual shipment, and no command comes while the player is away. So only
## automatic links start shipments, and shipments that are on their way
## arrive. Offline progress for a time gives the same state as ticks for the
## same time. Each rule that a later ticket adds to the tick works offline
## with no change. Returns what happened. Call it in parts, such as one part
## each frame, and add the summaries with [method OfflineSummary.add]: the
## state is the same as for one call.
func progress_offline(duration_ms: int) -> OfflineSummary:
	assert(duration_ms >= 0, "offline progress cannot be negative")
	var tally := OfflineSummary.new()
	tally.duration_ms = maxi(duration_ms, 0)
	_offline_tally = tally
	tick(tally.duration_ms)
	_offline_tally = null
	return tally


## The events of a tick that ends at [param end_ms]: the arrivals up to and at
## [param end_ms], and the demand event start and automatic starts before it.
## An event's order is the shipment id for an arrival, and the link index for
## an automatic start.
func _events_until(end_ms: int) -> EventQueue:
	var events := EventQueue.new()
	for i in _links.size():
		var state := _links[i]
		for shipment in state.shipments:
			_push_arrival(events, end_ms, state, shipment)
		if state.is_automatic():
			_push_automatic_start(events, end_ms, state, i)
	_push_demand_event_start(events, end_ms)
	return events


## Adds the arrival of [param shipment] on [param state] to [param events] if
## it is in the tick that ends at [param end_ms].
func _push_arrival(events: EventQueue, end_ms: int, state: LinkState, shipment: ShipmentState) -> void:
	if shipment.arrives_at_ms <= end_ms:
		events.push(shipment.arrives_at_ms, _EVENT_ARRIVAL, shipment.id, state, shipment)


## Adds the next automatic start of [param state], at [param index] in the
## links, to [param events] if it is before [param end_ms]. A tick that ends
## at a time leaves the starts at that time to the next tick.
func _push_automatic_start(events: EventQueue, end_ms: int, state: LinkState, index: int) -> void:
	if state.next_automatic_ms < end_ms:
		events.push(state.next_automatic_ms, _EVENT_AUTOMATIC_START, index, state)


## Adds the next demand event start to [param events] if it is before
## [param end_ms].
func _push_demand_event_start(events: EventQueue, end_ms: int) -> void:
	var next_ms := _demand.next_event_ms
	if next_ms != DemandState.UNSCHEDULED and next_ms < end_ms:
		events.push(next_ms, _EVENT_DEMAND_EVENT_START, 0)


## Does the automatic start of [param state], at [param index] in the links,
## that is due now. Adds the events that it makes to [param events] when they
## are in the tick that ends at [param end_ms]: the arrival of its shipment and
## the next start.
func _start_automatic_shipment(state: LinkState, index: int, events: EventQueue, end_ms: int) -> void:
	var shipment_count := state.shipments.size()
	var result := _start_shipment(state, true)
	state.record_automatic_start(result, _content.transport_tier(state.vehicle).transit_time_ms)
	if state.shipments.size() > shipment_count:
		_push_arrival(events, end_ms, state, state.shipments[-1])
	_push_automatic_start(events, end_ms, state, index)


# --- Queries ------------------------------------------------------------------

## Total simulated time.
func time_ms() -> int:
	return _time_ms


## The money the player has now.
func money() -> BigNumber:
	return _money


## The prisms owned, the prisms bought across all runs, and the price of the
## next prism.
func prisms() -> PrismView:
	var view := PrismView.new()
	view.owned = _prisms
	view.total_bought = _prisms_bought
	view.next_price = _prism_price()
	return view


## What [method prestige] does now: if it is allowed, and what it keeps and
## what it clears.
func prestige_preview() -> PrestigeView:
	var view := PrestigeView.new()
	var blocked := _prestige_blocked()
	view.allowed = blocked == null
	view.message = "" if blocked == null else blocked.message
	view.keeps = PackedStringArray(_PRESTIGE_KEEPS.keys())
	view.clears = _PRESTIGE_CLEARS.duplicate()
	return view


## All prestige upgrades, in content order, with their prices and whether the
## player owns them.
func prestige_upgrades() -> Array[PrestigeUpgradeView]:
	var views: Array[PrestigeUpgradeView] = []
	for def in _content.prestige_upgrades():
		views.append(_prestige_upgrade_view(def))
	return views


## The prestige upgrade with [param id], or null.
func prestige_upgrade(id: StringName) -> PrestigeUpgradeView:
	var def := _content.prestige_upgrade(id)
	return null if def == null else _prestige_upgrade_view(def)


## The money that [method build_factory] costs now.
func factory_build_cost() -> BigNumber:
	return _content.factory_balance.build_cost


## The transport tier the player has now.
func transport_tier() -> TransportTier:
	return _transport_tier


## The transport tier that [method buy_transport_tier] buys, or null when the
## player has the highest tier.
func next_transport_tier() -> TransportTier:
	var tiers := _content.transport_tiers()
	var rank := _transport_tier.rank + 1
	return tiers[rank] if rank < tiers.size() else null


## The money that [method buy_automatic_transport] costs now.
func automatic_transport_cost() -> BigNumber:
	return _content.automatic_transport_cost


## The money that [method build_lab] costs now.
func lab_build_cost() -> BigNumber:
	return _content.lab_build_cost


## The money that [method build_warehouse] costs now.
func warehouse_build_cost() -> BigNumber:
	return _content.warehouse_balance.build_cost


## True if the player can build warehouses now: when they have at least
## [member WarehouseBalance.unlock_factory_count] factories in the run.
## Factories are never removed in a run, so warehouses stay unlocked. Another
## unlock (such as research) changes only this function.
func is_warehouse_unlocked() -> bool:
	return _factories.size() >= _content.warehouse_balance.unlock_factory_count


## All warehouses, in build order, with their widgets and throughput.
func warehouses() -> Array[WarehouseView]:
	var views: Array[WarehouseView] = []
	for state in _warehouses:
		views.append(_warehouse_view(state))
	return views


## The warehouse with [param id], or null.
func warehouse(id: int) -> WarehouseView:
	var state := _warehouse_state(id)
	return null if state == null else _warehouse_view(state)


## The colors that [method build_factory] accepts now, in content order.
func buildable_factory_colors() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in _content.colors():
		if is_color_unlocked(def.id):
			ids.append(def.id)
	return ids


## True if the player can build factories of [param color] now: it is
## available from the start (see [enum ColorDef.Unlock]), or complete research
## or an owned prestige upgrade unlocks it, as its unlock says.
func is_color_unlocked(color: StringName) -> bool:
	var def := _content.color(color)
	if def == null:
		return false
	match def.unlock:
		ColorDef.Unlock.RESEARCH:
			return _research.unlocks_color(color, _content)
		ColorDef.Unlock.PRESTIGE_UPGRADE:
			for id in _prestige_upgrades:
				if _content.prestige_upgrade(id).unlocks_color(color):
					return true
			return false
	return true


## All labs, by id, in build order.
func labs() -> Array[int]:
	return _labs.duplicate()


## All research, in content order, with its status and progress.
func research() -> Array[ResearchView]:
	var views: Array[ResearchView] = []
	for def in _content.research():
		views.append(_research_view(def))
	return views


## The research with [param id], or null.
func research_item(id: StringName) -> ResearchView:
	var def := _content.research_def(id)
	return null if def == null else _research_view(def)


## The research that labs pay for now, or &"" when there is none.
func selected_research() -> StringName:
	return _research.selected


## Widgets that arrived at labs that no research needed when they arrived, as
## color id to count, in content order. They pay for the next research that
## needs them.
func lab_stock() -> Dictionary[StringName, int]:
	return _research.stock_counts(_content)


## All factories, in build order.
func factories() -> Array[FactoryView]:
	var views: Array[FactoryView] = []
	for state in _factories:
		views.append(_factory_view(state))
	return views


## The factory with [param id], or null.
func factory(id: int) -> FactoryView:
	var state := _factory_state(id)
	return null if state == null else _factory_view(state)


## All markets, open or not, in content order, with the remoteness of each,
## whether it is open, the demand and price of each color now, and the
## population, income, and capacity.
func markets() -> Array[MarketView]:
	var views: Array[MarketView] = []
	for def in _content.markets():
		views.append(_market_view(def))
	return views


## The demand events that are active now, in start order. Each one changes the
## demand of its colors in every market until it ends.
func demand_events() -> Array[DemandEventView]:
	return _demand.active_events(_time_ms)


## The forecast of the demand of each color in each market, open or not, at
## [param ahead_ms] from now (0 or more), and its accuracy. See
## [ForecastView]. A query draws nothing from the random number generator, so
## it does not change the future demand.
func forecast(ahead_ms: int) -> ForecastView:
	var view := ForecastView.new()
	view.ahead_ms = maxi(0, ahead_ms)
	view.at_ms = _time_ms + view.ahead_ms
	view.accuracy = forecast_accuracy()
	for def in _content.markets():
		var colors: Dictionary[StringName, float] = {}
		for color in def.prices:
			colors[color] = _demand.forecast(def.id, color, view.at_ms, view.accuracy, _content.demand_balance)
		view.demands[def.id] = colors
	return view


## How accurate the forecast is now, from 0 to 1: the base accuracy plus the
## forecast accuracy of each complete research, at most 1.
func forecast_accuracy() -> float:
	var accuracy := _content.forecast_balance.base_accuracy
	for id in _research.completed():
		accuracy += _content.research_def(id).forecast_accuracy
	return minf(1.0, accuracy)


## The time ahead that the screen shows the forecast for.
func forecast_horizon_ms() -> int:
	return _content.forecast_balance.horizon_ms


## The market with [param id], or null.
func market(id: StringName) -> MarketView:
	var def := _content.market(id)
	return null if def == null else _market_view(def)


## All links, in the order they were made.
func links() -> Array[LinkView]:
	var views: Array[LinkView] = []
	for state in _links:
		views.append(_link_view(state))
	return views


## The link with [param id], or null.
func link(id: int) -> LinkView:
	var state := _link_state(id)
	return null if state == null else _link_view(state)


## The split of each color at each source that has one, in the order of the
## first link from each source.
func splits() -> Array[SplitView]:
	var views: Array[SplitView] = []
	var seen := {}
	for state in _links:
		if not state.has_split() or seen.has(state):
			continue
		var view := SplitView.new()
		view.source_kind = state.source_kind
		view.source_factory_id = state.source_factory_id
		view.source_warehouse_id = state.source_warehouse_id
		view.color = state.color
		for other in _split_group(state):
			seen[other] = true
			view.shares[other.id] = other.split_percent
			view.shipped[other.id] = other.split_shipped
		views.append(view)
	return views


## True if a link goes from the factory [param factory_id] to the market
## [param market_id].
func has_link(factory_id: int, market_id: StringName) -> bool:
	for state in _links:
		if state.comes_from_factory(factory_id) and state.goes_to_market(market_id):
			return true
	return false


## True if a link goes from the factory [param source_id] to the lab
## [param lab_id].
func has_lab_link(source_id: int, lab_id: int) -> bool:
	for state in _links:
		if state.comes_from_factory(source_id) and state.goes_to_lab(lab_id):
			return true
	return false


## True if a link goes from the factory [param source_id] to the factory
## [param destination_id].
func has_factory_link(source_id: int, destination_id: int) -> bool:
	for state in _links:
		if state.comes_from_factory(source_id) and state.goes_to_factory(destination_id):
			return true
	return false


## The full state as plain data. Two simulations with equal snapshots behave
## the same from here on. Use it to compare states, not to read single values.
func snapshot() -> Dictionary:
	var factory_dicts: Array[Dictionary] = []
	for state in _factories:
		factory_dicts.append(state.to_dict())
	var link_dicts: Array[Dictionary] = []
	for state in _links:
		link_dicts.append(state.to_dict())
	return {
		"time_ms": _time_ms,
		"rng": _rng.get_state(),
		"money": _money.to_data(),
		"next_factory_id": _next_factory_id,
		"factories": factory_dicts,
		"next_link_id": _next_link_id,
		"links": link_dicts,
		"next_shipment_id": _next_shipment_id,
		"next_warehouse_id": _next_warehouse_id,
		"warehouses": _warehouses.map(func(w: WarehouseState) -> Dictionary: return w.to_dict()),
		"prisms": _prisms,
		"prisms_bought": _prisms_bought,
		"prestige_upgrades": _prestige_upgrades.map(func(id: StringName) -> String: return String(id)),
		"markets": _markets_to_dicts(),
		"transport_tier": _transport_tier.id,
		"next_lab_id": _next_lab_id,
		"labs": _labs.map(func(id: int) -> Dictionary: return {"id": id}),
	}.merged(_demand.to_dict()).merged(_research.to_dict(_content))


## The markets for [method snapshot], in content order.
func _markets_to_dicts() -> Array[Dictionary]:
	var dicts: Array[Dictionary] = []
	for def in _content.markets():
		dicts.append(_markets[def.id].to_dict())
	return dicts


# --- Internal -----------------------------------------------------------------

## The shipment size rule, in one place: how many of [param available] widgets
## a shipment on [param state] carries, which is what its destination accepts
## when the shipment leaves. A mixed factory accepts the free space in the
## input bay of the link's color, and a warehouse its free space, each less
## the widgets already on their way, so that the bay or the warehouse cannot
## overflow when they arrive. A market accepts the capacity that is left in
## the current period: its capacity less the widgets it sold in this period
## and the widgets on their way to it. So a market never gets more widgets
## than its capacity, and there is no overflow rule. Widgets on their way
## count against the capacity of each period until they arrive, and a sale
## counts against the period in which it arrives. A lab accepts what the
## selected research still needs of the link's color, less the widgets already
## on their way to labs and in the lab stock, so that labs get no more than the
## research needs.
func _accepted_count(state: LinkState, available: int) -> int:
	var free := 0
	if state.destination_kind == LinkView.Destination.FACTORY:
		var destination := _factory_state(state.destination_factory_id)
		free = _content.factory_balance.input_bay_capacity \
			- destination.input_bays[state.color] \
			- _widgets_in_transit_to(destination.id, state.color)
	elif state.destination_kind == LinkView.Destination.WAREHOUSE:
		free = _content.warehouse_balance.space \
			- _warehouse_state(state.destination_warehouse_id).count \
			- _widgets_in_transit_to_warehouse(state.destination_warehouse_id)
	elif state.destination_kind == LinkView.Destination.LAB:
		free = _research.needs(state.color, _content) - _widgets_in_transit_to_labs(state.color) \
			- _research.stock(state.color)
	else:
		free = _capacity_left(_markets[state.destination_market_id])
	return clampi(free, 0, available)


## The capacity that [param market] has left now for a shipment that leaves
## now. It can be less than 0 after a load of an old save.
func _capacity_left(market: MarketState) -> int:
	return market.capacity(_content.market_balance) \
		- market.capacity_used(_time_ms, _content.market_balance) \
		- _widgets_in_transit_to_market(market.id)


## Widgets in shipments on their way to the market [param market_id].
func _widgets_in_transit_to_market(market_id: StringName) -> int:
	var count := 0
	for state in _links:
		if state.goes_to_market(market_id):
			count += state.widgets_in_transit()
	return count


## The split rule, in one place: how many of [param available] widgets at the
## source an automatic start on [param state] may carry. With no split, all of them.
## With a split, the link may carry up to its percentage of all the widgets
## that the source had since the split was set (the widgets that its links
## shipped since then, plus [param available]), less what it shipped. Thus a
## link that ships often does not take the share of a link that ships less
## often, and a link that cannot take widgets for a time keeps its share, so
## it gets them later. A blocked link can fill the source and stop it.
## Widgets that a shipment by hand takes leave the source and are not in the
## total, so the percentages apply to the widgets of automatic starts.
func _split_allowance(state: LinkState, available: int) -> int:
	if not state.has_split():
		return available
	var total := available
	for other in _split_group(state):
		total += other.split_shipped
	@warning_ignore("integer_division")
	return clampi(state.split_percent * total / 100 - state.split_shipped, 0, available)


## The links that share a split with [param state]: the links from its source
## with its color, in link order. It includes [param state] when it is a link
## of the simulation.
func _split_group(state: LinkState) -> Array[LinkState]:
	var group: Array[LinkState] = []
	for other in _links:
		if other.same_source_as(state):
			group.append(other)
	return group


## Widgets of [param color] in shipments on their way to the factory
## [param factory_id].
func _widgets_in_transit_to(factory_id: int, color: StringName) -> int:
	var count := 0
	for state in _links:
		if state.color == color and state.goes_to_factory(factory_id):
			count += state.widgets_in_transit()
	return count


## Widgets in shipments on their way to the warehouse [param warehouse_id].
func _widgets_in_transit_to_warehouse(warehouse_id: int) -> int:
	var count := 0
	for state in _links:
		if state.goes_to_warehouse(warehouse_id):
			count += state.widgets_in_transit()
	return count


## Widgets of [param color] in shipments on their way to any lab.
func _widgets_in_transit_to_labs(color: StringName) -> int:
	var count := 0
	for state in _links:
		if state.color == color and state.destination_kind == LinkView.Destination.LAB:
			count += state.widgets_in_transit()
	return count


## The sell threshold rule, in one place: true when [param state] is an
## automatic link from a warehouse with a sell threshold to a market, and the
## demand for its color there now, as a whole percent, is below the threshold.
## The percent is rounded as the screen shows it, so the player sees the hold
## start and end at the number they set. A manual link never holds.
func _is_held(state: LinkState) -> bool:
	if state.source_kind != LinkView.Source.WAREHOUSE or state.destination_kind != LinkView.Destination.MARKET \
			or not state.is_automatic():
		return false
	var threshold := _warehouse_state(state.source_warehouse_id).sell_threshold
	if threshold == WarehouseView.NO_SELL_THRESHOLD:
		return false
	var demand := _demand.demand(state.destination_market_id, state.color, _time_ms, _content.demand_balance)
	return MarketView.demand_percent(demand) < threshold


## Widgets that the source of [param state] has to ship now.
func _source_count(state: LinkState) -> int:
	if state.source_kind == LinkView.Source.WAREHOUSE:
		return _warehouse_state(state.source_warehouse_id).count
	return _factory_state(state.source_factory_id).output_bay_count


## Delivers [param shipment] of [param state], which arrives now: a market
## sells it, a mixed factory puts it into the input bay of its color, a
## warehouse holds it, and a lab consumes it to pay for the selected research.
func _deliver(state: LinkState, shipment: ShipmentState) -> void:
	state.shipments.erase(shipment)
	match state.destination_kind:
		LinkView.Destination.FACTORY:
			_factory_state(state.destination_factory_id).deliver(state.color, shipment.count,
				_content.factory_balance)
		LinkView.Destination.WAREHOUSE:
			_warehouse_state(state.destination_warehouse_id).deliver(shipment.count,
				_content.warehouse_balance.space)
		LinkView.Destination.LAB:
			_research.deliver(state.color, shipment.count, _content)
		_:
			_sell(state, shipment)


## The market at the end of [param state] buys [param shipment] at its price
## for the link's color when the shipment arrives, which can be before now in
## a long tick. Then the sale saturates that color in that market. All widgets
## of one shipment sell at the same price. The sale uses capacity of the
## period in which it arrives. It is never more than the capacity left,
## because the widgets on their way counted against capacity when they left.
func _sell(state: LinkState, shipment: ShipmentState) -> void:
	var market_id := state.destination_market_id
	var at_ms := shipment.arrives_at_ms
	var def := _content.market(market_id)
	var price := _price(def, state.color, _demand.demand(market_id, state.color, at_ms, _content.demand_balance))
	var earned := price.mul(BigNumber.from_int(shipment.count))
	_money = _money.add(earned)
	if _offline_tally != null:
		_offline_tally.money_earned = _offline_tally.money_earned.add(earned)
		_offline_tally.widgets_sold += shipment.count
	_demand.record_sale(market_id, state.color, shipment.count, at_ms, _content.demand_balance)
	_markets[market_id].record_sale(shipment.count, at_ms, _content.market_balance)


## The price of one widget of [param color] in [param def] at [param demand]:
## the base price times demand, times the factor from the market's income.
func _price(def: MarketDef, color: StringName, demand: float) -> BigNumber:
	var factor := _content.market_balance.income_factor(_markets[def.id].income)
	return def.price(color).mul(BigNumber.from_float(demand * factor))


func _investment_cost(state: MarketState, goal: MarketView.Investment) -> BigNumber:
	return _content.market_balance.investment_cost_after(state.investments(goal))


func _prism_price() -> BigNumber:
	return _content.prism_balance.price(_prisms_bought)


## The money at the start of a run: that of the content, plus the bonuses of
## the owned prestige upgrades.
func _starting_money() -> BigNumber:
	var money := _content.starting_money
	for id in _prestige_upgrades:
		money = money.add(_content.prestige_upgrade(id).starting_money)
	return money


## How many times as fast factories make widgets: the product of the bonuses
## of the owned prestige upgrades, in content order, so that the same
## upgrades always give the same value.
func _production_speed() -> float:
	var speed := 1.0
	for id in _prestige_upgrades:
		speed *= _content.prestige_upgrade(id).production_speed
	return speed


## The time for one production line to make one widget now: the time in the
## content, divided by [method _production_speed], to the nearest whole
## millisecond, and at least 1. Time is an integer so that production stays
## exact for ticks of any length.
func _widget_time_ms() -> int:
	return maxi(1, roundi(_content.factory_balance.widget_time_ms / _production_speed()))


## The factory with [param id], or null, with its widgets made up to now.
## Inside a tick, a factory makes widgets only when an event uses it, and the
## events use it through this function. Its production is exact for any
## duration, so this gives the same state as advancing every factory at each
## event, at a cost for each event that does not grow with the factory count.
## Rules that read or change a factory inside a tick must get it here.
func _factory_state(id: int) -> FactoryState:
	var state: FactoryState = _factories_by_id.get(id)
	if state != null:
		_sync(state)
	return state


## Makes widgets in [param state] up to now.
func _sync(state: FactoryState) -> void:
	if state.synced_ms == _time_ms:
		return
	var made := state.advance(_time_ms - state.synced_ms, _content.factory_balance, _widget_time_ms())
	state.synced_ms = _time_ms
	if _offline_tally != null:
		_offline_tally.widgets_made += made


func _warehouse_state(id: int) -> WarehouseState:
	for state in _warehouses:
		if state.id == id:
			return state
	return null


func _link_state(id: int) -> LinkState:
	for state in _links:
		if state.id == id:
			return state
	return null


func _factory_view(state: FactoryState) -> FactoryView:
	var view := state.to_view(_content.factory_balance)
	for bay in view.input_bays:
		bay.in_transit = _widgets_in_transit_to(state.id, bay.color)
	return view


func _prestige_upgrade_view(def: PrestigeUpgradeDef) -> PrestigeUpgradeView:
	var view := PrestigeUpgradeView.new()
	view.id = def.id
	view.name = def.name
	view.price = def.price
	view.owned = _prestige_upgrades.has(def.id)
	view.production_speed = def.production_speed
	view.starting_money = def.starting_money
	view.unlock_colors = def.unlock_colors
	return view


func _research_view(def: ResearchDef) -> ResearchView:
	var in_transit: Dictionary[StringName, int] = {}
	for color in def.cost:
		in_transit[color] = _widgets_in_transit_to_labs(color)
	return _research.to_view(def, in_transit)


## Such as "Green factory #4".
func _factory_name(state: FactoryState) -> String:
	return "%s factory #%d" % [_content.color(state.color).name, state.id]


## Such as "Green warehouse #2".
func _warehouse_name(state: WarehouseState) -> String:
	return "%s warehouse #%d" % [_content.color(state.color).name, state.id]


## Such as "green", for text inside a sentence.
func _color_text(color: StringName) -> String:
	return _content.color(color).name.to_lower()


## The start of [param state], such as "Red factory #1" or "Red warehouse #2".
func _source_name(state: LinkState) -> String:
	if state.source_kind == LinkView.Source.WAREHOUSE:
		return _warehouse_name(_warehouse_state(state.source_warehouse_id))
	return _factory_name(_factory_state(state.source_factory_id))


## The end of [param state], such as "Millbrook" or "Green factory #4".
func _destination_name(state: LinkState) -> String:
	match state.destination_kind:
		LinkView.Destination.FACTORY:
			return _factory_name(_factory_state(state.destination_factory_id))
		LinkView.Destination.WAREHOUSE:
			return _warehouse_name(_warehouse_state(state.destination_warehouse_id))
		LinkView.Destination.LAB:
			return "Lab #%d" % state.destination_lab_id
	return _content.market(state.destination_market_id).name


func _warehouse_view(state: WarehouseState) -> WarehouseView:
	var view := state.to_view(_content.warehouse_balance.space)
	view.in_transit = _widgets_in_transit_to_warehouse(state.id)
	for link_state in _links:
		if link_state.goes_to_warehouse(state.id):
			view.inflow_per_minute += link_state.widgets_per_minute(_time_ms)
		elif link_state.comes_from_warehouse(state.id):
			view.outflow_per_minute += link_state.widgets_per_minute(_time_ms)
			if _is_held(link_state):
				view.held_market_ids.append(link_state.destination_market_id)
	return view


func _link_view(state: LinkState) -> LinkView:
	return state.to_view(_content.transport_tier(state.vehicle), _time_ms)


func _market_view(def: MarketDef) -> MarketView:
	var balance := _content.market_balance
	var state := _markets[def.id]
	var view := MarketView.new()
	view.id = def.id
	view.name = def.name
	view.population = state.population
	view.income = state.income
	view.capacity = state.capacity(balance)
	view.capacity_used = state.capacity_used(_time_ms, balance)
	view.capacity_in_transit = _widgets_in_transit_to_market(def.id)
	view.capacity_left = maxi(0, _capacity_left(state))
	view.period_ends_in_ms = balance.period_end_ms(_time_ms) - _time_ms
	view.population_investment_cost = _investment_cost(state, MarketView.Investment.POPULATION)
	view.income_investment_cost = _investment_cost(state, MarketView.Investment.INCOME)
	view.remoteness = def.remoteness
	var needed := _content.tier_for_remoteness(def.remoteness)
	view.needed_tier = &"" if needed == null else needed.id
	view.is_open = _transport_tier.reaches(def.remoteness)
	for color in def.prices:
		var demand := _demand.demand(def.id, color, _time_ms, _content.demand_balance)
		view.demands[color] = demand
		view.prices[color] = _price(def, color, demand)
	return view
