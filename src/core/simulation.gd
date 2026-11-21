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

var _content: Content
var _rng: SimRng
var _time_ms: int = 0
var _money: BigNumber
var _next_factory_id: int = 1
var _factories: Array[FactoryState] = []
var _next_link_id: int = 1
var _links: Array[LinkState] = []
var _next_shipment_id: int = 1


## [param p_content] must be valid (no [member Content.errors]).
func _init(p_content: Content, p_seed: int) -> void:
	assert(p_content.errors.is_empty(), "Simulation needs valid content: %s" % "; ".join(p_content.errors))
	_content = p_content
	_rng = SimRng.new(p_seed)
	_money = _content.starting_money


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
	for factory_reader in reader.objects("factories"):
		var state := FactoryState.from_snapshot(factory_reader, p_content)
		if ids.has(state.id):
			factory_reader.fail("id", "is used by more than one factory")
		elif state.id >= sim._next_factory_id:
			factory_reader.fail("id", "must be less than next_factory_id (%d)" % sim._next_factory_id)
		ids[state.id] = true
		sim._factories.append(state)
	sim._read_links(reader)
	return sim


## Reads the links and their shipments for [method from_snapshot], and checks
## them against the factories and the time, which it has read first.
func _read_links(reader: SnapshotReader) -> void:
	_next_link_id = reader.integer("next_link_id", 1)
	_next_shipment_id = reader.integer("next_shipment_id", 1)
	var link_ids := {}
	var shipment_ids := {}
	var routes := {}
	for link_reader in reader.objects("links"):
		var state := LinkState.from_snapshot(link_reader, _content, _time_ms,
			_next_shipment_id, shipment_ids)
		if link_ids.has(state.id):
			link_reader.fail("id", "is used by more than one link")
		elif state.id >= _next_link_id:
			link_reader.fail("id", "must be less than next_link_id (%d)" % _next_link_id)
		link_ids[state.id] = true
		var source := _factory_state(state.source_factory_id)
		if source == null:
			link_reader.fail("source_factory_id", "there is no factory #%d" % state.source_factory_id)
		elif source.color != state.color:
			link_reader.fail("color", "must be the color of factory #%d (%s)" % [source.id, source.color])
		var ends := [state.source_factory_id, state.destination_market_id]
		if routes.has(ends):
			link_reader.fail("destination_market_id", "factory #%d has more than one link to %s" % ends)
		routes[ends] = true
		_links.append(state)


# --- Commands -----------------------------------------------------------------

## Builds a base factory of [param color] for [method factory_build_cost]. On
## success, [member CommandResult.value] is the new factory id.
func build_factory(color: StringName) -> CommandResult:
	var color_def := _content.color(color)
	if color_def == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_COLOR,
			"There is no color \"%s\"." % color)
	if not color_def.is_base():
		return CommandResult.failure(CommandResult.Reason.NOT_A_BASE_COLOR,
			"%s needs inputs, so it cannot have a base factory." % color_def.name)
	var cost := factory_build_cost()
	if _money.is_less_than(cost):
		return _not_enough_money("A factory", cost)

	_money = _money.sub(cost)
	var state := FactoryState.new(_next_factory_id, color)
	_next_factory_id += 1
	_factories.append(state)
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
## [param market_id]. The link carries the factory's color, and its vehicle is
## the first transport tier. Making a link is free; each shipment costs money.
## On success, [member CommandResult.value] is the new link id.
func make_link(factory_id: int, market_id: StringName) -> CommandResult:
	var source := _factory_state(factory_id)
	if source == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_FACTORY,
			"There is no factory #%d." % factory_id)
	var market := _content.market(market_id)
	if market == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_MARKET,
			"There is no market \"%s\"." % market_id)
	if has_link(factory_id, market_id):
		return CommandResult.failure(CommandResult.Reason.LINK_EXISTS,
			"Factory #%d already has a link to %s." % [factory_id, market.name])

	var state := LinkState.new(_next_link_id, source.color, factory_id, market_id,
		_content.transport_tiers()[0].id)
	_next_link_id += 1
	_links.append(state)
	return CommandResult.success(state.id)


## Starts a shipment on the link [param link_id] by hand. It costs the
## vehicle's shipment cost now and arrives after the vehicle's transit time,
## when the market sells it. It carries the widgets in the source's output bay,
## up to what the destination accepts now (see [method _accepted_count]). On
## success, [member CommandResult.value] is the widget count.
func start_shipment(link_id: int) -> CommandResult:
	var state := _link_state(link_id)
	if state == null:
		return CommandResult.failure(CommandResult.Reason.UNKNOWN_LINK,
			"There is no link #%d." % link_id)
	return _start_shipment(state)


## Buys automatic transport for the link [param link_id], for
## [method automatic_transport_cost]. From now on, the link starts a shipment
## by itself now and then once each transit time of its vehicle, by the rules
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


## Starts a shipment on [param state] if the rules allow it, for
## [method start_shipment] and for automatic starts.
func _start_shipment(state: LinkState) -> CommandResult:
	var source := _factory_state(state.source_factory_id)
	var count := _accepted_count(state, source.output_bay_count)
	if count <= 0:
		var why := "Factory #%d has no widgets." % source.id if source.output_bay_count <= 0 \
			else "%s accepts no widgets now." % _content.market(state.destination_market_id).name
		return CommandResult.failure(CommandResult.Reason.NOTHING_TO_SHIP,
			"Nothing to ship: %s" % why)
	var tier := _content.transport_tier(state.vehicle)
	if _money.is_less_than(tier.shipment_cost):
		return _not_enough_money("A shipment by %s" % tier.name.to_lower(), tier.shipment_cost)

	_money = _money.sub(tier.shipment_cost)
	source.take_output(count)
	state.add_shipment(_next_shipment_id, count, _time_ms, tier.transit_time_ms)
	_next_shipment_id += 1
	return CommandResult.success(count)


func _not_enough_money(what: String, cost: BigNumber) -> CommandResult:
	return CommandResult.failure(CommandResult.Reason.NOT_ENOUGH_MONEY,
		"%s costs %s, but you have only %s." % [what, cost.format(), _money.format()])


# --- Time ---------------------------------------------------------------------

## Advances the simulation by [param duration_ms] milliseconds. Time is an
## integer so that one long tick gives the same state as many short ticks.
##
## Inside the tick, things happen in time order. Factories make widgets until
## the next event, then the event happens. The events are shipment arrivals,
## which sell, and automatic starts. At one time, arrivals sell first, so their
## money can pay for automatic starts at that time. A tick that ends at a time
## sells the arrivals at that time, and the next tick does the automatic starts
## at that time, so that ticks of any length give the same state. A tick takes
## time in proportion to the size of the state and the number of events.
func tick(duration_ms: int) -> void:
	assert(duration_ms >= 0, "tick duration cannot be negative")
	if duration_ms <= 0:
		return
	var end_ms := _time_ms + duration_ms
	while true:
		var event_ms := mini(end_ms, _next_event_ms())
		for state in _factories:
			state.advance(event_ms - _time_ms, _content.factory_balance)
		_time_ms = event_ms
		_sell_arrived_shipments()
		if _time_ms == end_ms:
			break
		_start_automatic_shipments()
	for state in _links:
		state.forget_old_starts(_time_ms)


## The time of the next event: the earliest arrival after now or automatic
## start from now on. A large time when there is none.
func _next_event_ms() -> int:
	var next_ms := 9223372036854775807
	for state in _links:
		if state.is_automatic():
			next_ms = mini(next_ms, state.next_automatic_ms)
		for shipment in state.shipments:
			next_ms = mini(next_ms, shipment.arrives_at_ms)
	return next_ms


## Does each automatic start that is due now, in link order.
func _start_automatic_shipments() -> void:
	for state in _links:
		if not state.is_automatic() or state.next_automatic_ms != _time_ms:
			continue
		var result := _start_shipment(state)
		match result.reason:
			CommandResult.Reason.NONE:
				state.automatic_status = LinkState.SHIPPED
			CommandResult.Reason.NOT_ENOUGH_MONEY:
				state.automatic_status = LinkState.NOT_ENOUGH_MONEY
			_:
				assert(result.reason == CommandResult.Reason.NOTHING_TO_SHIP, "unexpected %s" % result.message)
				state.automatic_status = LinkState.NOTHING_TO_SHIP
		state.next_automatic_ms += _content.transport_tier(state.vehicle).transit_time_ms


# --- Queries ------------------------------------------------------------------

## Total simulated time.
func time_ms() -> int:
	return _time_ms


## The money the player has now.
func money() -> BigNumber:
	return _money


## The money that [method build_factory] costs now.
func factory_build_cost() -> BigNumber:
	return _content.factory_balance.build_cost


## The money that [method buy_automatic_transport] costs now.
func automatic_transport_cost() -> BigNumber:
	return _content.automatic_transport_cost


## The colors that [method build_factory] accepts now, in content order.
func buildable_factory_colors() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in _content.colors():
		if def.is_base():
			ids.append(def.id)
	return ids


## All factories, in build order.
func factories() -> Array[FactoryView]:
	var views: Array[FactoryView] = []
	for state in _factories:
		views.append(state.to_view(_content.factory_balance))
	return views


## The factory with [param id], or null.
func factory(id: int) -> FactoryView:
	var state := _factory_state(id)
	return null if state == null else state.to_view(_content.factory_balance)


## All markets that are open, in content order.
func markets() -> Array[MarketView]:
	var views: Array[MarketView] = []
	for def in _content.markets():
		views.append(_market_view(def))
	return views


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


## True if a link goes from the factory [param factory_id] to the market
## [param market_id].
func has_link(factory_id: int, market_id: StringName) -> bool:
	for state in _links:
		if state.source_factory_id == factory_id and state.destination_market_id == market_id:
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
	}


# --- Internal -----------------------------------------------------------------

## The shipment size rule, in one place: how many of [param available] widgets
## a shipment on [param state] carries, which is what its destination accepts
## when the shipment leaves. A market accepts all widgets for now. Later rules
## (free input bay space, free warehouse space, and market capacity left in the
## period) go here.
func _accepted_count(state: LinkState, available: int) -> int:
	assert(_content.market(state.destination_market_id) != null, "links go to markets")
	return available


## Sells every shipment that has arrived by now. Sales happen in arrival order
## (then start order), so one long tick adds money in the same order as many
## short ticks. BigNumber sums are float sums, so the order matters.
func _sell_arrived_shipments() -> void:
	var arrived: Array[Dictionary] = []
	for state in _links:
		var in_transit: Array[ShipmentState] = []
		for shipment in state.shipments:
			if shipment.arrives_at_ms <= _time_ms:
				arrived.append({"link": state, "shipment": shipment})
			else:
				in_transit.append(shipment)
		state.shipments = in_transit
	arrived.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.shipment.arrives_before(b.shipment))
	for entry in arrived:
		_sell(entry.link, entry.shipment.count)


## The market at the end of [param state] buys [param count] widgets at its
## current price for the link's color.
func _sell(state: LinkState, count: int) -> void:
	var price := _content.market(state.destination_market_id).price(state.color)
	_money = _money.add(price.mul(BigNumber.from_int(count)))


func _factory_state(id: int) -> FactoryState:
	for state in _factories:
		if state.id == id:
			return state
	return null


func _link_state(id: int) -> LinkState:
	for state in _links:
		if state.id == id:
			return state
	return null


func _link_view(state: LinkState) -> LinkView:
	return state.to_view(_content.transport_tier(state.vehicle), _time_ms)


func _market_view(def: MarketDef) -> MarketView:
	var view := MarketView.new()
	view.id = def.id
	view.name = def.name
	view.prices = def.prices
	return view
