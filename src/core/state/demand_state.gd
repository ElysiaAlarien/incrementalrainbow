extends RefCounted
## Internal to the core. The demand of each color in each market, from drift,
## saturation, and demand events. Code outside src/core reads demand through
## MarketView, and demand events through DemandEventView. See ADR-0011.
##
## Demand is drift times saturation times the factor of each active demand
## event of the color, and the price is the base price times demand. 1 is
## normal demand.
## [br]- Drift is a pure function of time. One draw from the simulation's
##   random number generator at the start of the game sets [member drift_key].
##   The key and the market and color ids seed one value for each drift knot,
##   and drift moves smoothly from one knot to the next. So a tick does no work
##   for drift, one long tick gives the same drift as many short ticks, and
##   the demand at a future time is known.
## [br]- Saturation of a color in a market is the time when it recovers fully.
##   Each sold widget moves that time later by
##   [member DemandBalance.saturation_ms_per_widget], and saturation recovers
##   at a constant rate. Integer time keeps it exact.
## [br]- Demand events start at times that the simulation's random number
##   generator sets. The state holds the time of the next start. When the
##   tick reaches it, the generator chooses the event and the time of the
##   start after it. The draws happen at those times in the tick's event
##   order, so ticks of any length give the same events. An event changes its
##   colors in every market, from its start up to its end.

const DemandState := preload("res://src/core/state/demand_state.gd")
const DemandEventState := preload("res://src/core/state/demand_event_state.gd")

const _MASK32 := 0xFFFFFFFF
const _FNV_OFFSET := 0x811C9DC5
const _FNV_PRIME := 0x01000193
## Mixed into the pair hash of the forecast noise, so that the noise of a
## market and color has knot values of its own, not those of its drift.
const _FORECAST_DOMAIN := "forecast"

## The value of [member next_event_ms] when no start is set: when the content
## has no demand events, or after a load of a save from before demand events.
const UNSCHEDULED := -1

## The u32 that seeds drift. It does not change during a game.
var drift_key: int
## Market id to color id to the time when saturation of that color in that
## market has fully recovered. Only colors with saturation now are here.
var _saturated_until_ms: Dictionary[StringName, Dictionary] = {}
## The time when the next demand event starts, or [constant UNSCHEDULED].
var next_event_ms: int = UNSCHEDULED
## The demand events that have started and that a tick has not forgotten yet,
## in start order.
var _events: Array[DemandEventState] = []
## Drift values that a sale used, so that the next sale does not compute them
## again. It is not state: a new DemandState computes the same values. Market
## id to color id to [code][pair, knot, a, b][/code]: the pair hash, the knot
## index, and the values of that knot and the next one.
var _drift_cache: Dictionary[StringName, Dictionary] = {}


func _init(p_drift_key: int) -> void:
	drift_key = p_drift_key & _MASK32


## The demand of [param color] in [param market_id] at [param at_ms].
func demand(market_id: StringName, color: StringName, at_ms: int, balance: DemandBalance) -> float:
	return drift(market_id, color, at_ms, balance) * saturation_factor(market_id, color, at_ms, balance) \
		* event_factor(color, at_ms)


## The forecast of the demand of [param color] in [param market_id] at
## [param at_ms], with [param accuracy] from 0 to 1. It is [method demand] at
## that time with the state of now, except drift: the forecast drift is the
## real drift by [param accuracy] and forecast noise by the rest. The noise is
## a second drift with knot values of its own. It is a pure function of the
## drift key, the ids, and the time, so the forecast draws nothing from the
## simulation's random number generator, and it is the same each time. A
## demand event that has not started is not in the forecast, because the
## generator chooses it only at its start.
func forecast(market_id: StringName, color: StringName, at_ms: int, accuracy: float,
		balance: DemandBalance) -> float:
	var real := drift(market_id, color, at_ms, balance)
	var noise := _drift_of_pair(_forecast_pair_hash(market_id, color), at_ms, balance)
	return lerpf(noise, real, accuracy) * saturation_factor(market_id, color, at_ms, balance) \
		* event_factor(color, at_ms)


## The demand event part of demand: the product of the factors of the events
## of [param color] that are active at [param at_ms], or 1 with none.
func event_factor(color: StringName, at_ms: int) -> float:
	var factor := 1.0
	for event in _events:
		if event.is_active_at(at_ms) and event.def.has_color(color):
			factor *= event.def.factor()
	return factor


## Sets the time of the next demand event from [param now_ms] when none is
## set and [param content] has demand events. When it has none, clears it.
func schedule_events(now_ms: int, rng: SimRng, content: Content) -> void:
	if content.demand_events().is_empty():
		next_event_ms = UNSCHEDULED
	elif next_event_ms == UNSCHEDULED:
		next_event_ms = now_ms + _event_interval(rng, content.demand_balance)


## Starts each demand event that is due by [param now_ms], in time order. For
## each one, [param rng] chooses the event, then the time of the next start.
func start_due_events(now_ms: int, rng: SimRng, content: Content) -> void:
	var defs := content.demand_events()
	# [method schedule_events] clears the next start when there are no events.
	while next_event_ms != UNSCHEDULED and next_event_ms <= now_ms and not defs.is_empty():
		var def := defs[rng.randi_range(0, defs.size() - 1)]
		_events.append(DemandEventState.new(def, next_event_ms, next_event_ms + def.duration_ms))
		next_event_ms += _event_interval(rng, content.demand_balance)


## The demand events that are active at [param now_ms], in start order.
func active_events(now_ms: int) -> Array[DemandEventView]:
	var views: Array[DemandEventView] = []
	for event in _events:
		if event.is_active_at(now_ms):
			views.append(event.to_view(now_ms))
	return views


static func _event_interval(rng: SimRng, balance: DemandBalance) -> int:
	return rng.randi_range(balance.event_interval_min_ms, balance.event_interval_max_ms)


## The drift part of demand: from 1 - amplitude to 1 + amplitude.
func drift(market_id: StringName, color: StringName, at_ms: int, balance: DemandBalance) -> float:
	if balance.drift_amplitude == 0.0:
		return 1.0
	@warning_ignore("integer_division")
	var knot := at_ms / balance.drift_period_ms
	var knots := _knots(market_id, color, knot)
	return _between_knots(knots[2], knots[3], knot, at_ms, balance)


## A drift value, as in [method drift], from knot values of [param pair],
## with no cache.
func _drift_of_pair(pair: int, at_ms: int, balance: DemandBalance) -> float:
	if balance.drift_amplitude == 0.0:
		return 1.0
	@warning_ignore("integer_division")
	var knot := at_ms / balance.drift_period_ms
	return _between_knots(_knot_value(pair, knot), _knot_value(pair, knot + 1), knot, at_ms, balance)


## The drift at [param at_ms], from the values [param a] of [param knot] and
## [param b] of the knot after it: a smooth move from a to b.
static func _between_knots(a: float, b: float, knot: int, at_ms: int, balance: DemandBalance) -> float:
	var t := float(at_ms - knot * balance.drift_period_ms) / balance.drift_period_ms
	var smooth := t * t * (3.0 - 2.0 * t)
	return 1.0 + balance.drift_amplitude * (2.0 * lerpf(a, b, smooth) - 1.0)


## The saturation part of demand: 1 with no recent sales, 0.5 after
## [member DemandBalance.saturation_half_widgets] recent widgets, and more than
## 0 always.
func saturation_factor(market_id: StringName, color: StringName, at_ms: int,
		balance: DemandBalance) -> float:
	var widgets := saturation_widgets(market_id, color, at_ms, balance)
	return 1.0 / (1.0 + widgets / balance.saturation_half_widgets)


## The count of recent widgets that saturation of [param color] in
## [param market_id] still holds at [param at_ms]. It falls at one widget each
## [member DemandBalance.saturation_ms_per_widget].
func saturation_widgets(market_id: StringName, color: StringName, at_ms: int,
		balance: DemandBalance) -> float:
	if balance.saturation_ms_per_widget == 0:
		return 0.0
	var remaining_ms := _until_ms(market_id, color) - at_ms
	if remaining_ms <= 0:
		return 0.0
	return float(remaining_ms) / balance.saturation_ms_per_widget


## Adds the saturation of [param count] widgets of [param color] sold in
## [param market_id] at [param at_ms].
func record_sale(market_id: StringName, color: StringName, count: int, at_ms: int,
		balance: DemandBalance) -> void:
	if balance.saturation_ms_per_widget == 0 or count <= 0:
		return
	var start := maxi(_until_ms(market_id, color), at_ms)
	if not _saturated_until_ms.has(market_id):
		_saturated_until_ms[market_id] = {}
	_saturated_until_ms[market_id][color] = start + count * balance.saturation_ms_per_widget


## Forgets saturation that has fully recovered by [param now_ms], and demand
## events that have ended by then, so that the state holds only what has an
## effect.
func prune(now_ms: int) -> void:
	_events = _events.filter(func(event: DemandEventState) -> bool: return event.ends_at_ms > now_ms)
	for market_id in _saturated_until_ms.keys():
		var colors: Dictionary = _saturated_until_ms[market_id]
		for color: StringName in colors.keys():
			if colors[color] <= now_ms:
				colors.erase(color)
		if colors.is_empty():
			_saturated_until_ms.erase(market_id)


## The state as plain data for [method Simulation.snapshot]: the keys
## "drift_key", "saturation", "demand_events", and "next_demand_event_ms".
## Saturation is sorted by market and color, and events are in start order, so
## that equal states give equal snapshots.
func to_dict() -> Dictionary:
	var events: Array[Dictionary] = []
	for event in _events:
		events.append(event.to_dict())
	return {
		"drift_key": drift_key,
		"saturation": _saturation_to_list(),
		"demand_events": events,
		"next_demand_event_ms": next_event_ms,
	}


func _saturation_to_list() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var market_ids := _saturated_until_ms.keys()
	market_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for market_id: StringName in market_ids:
		var colors: Dictionary = _saturated_until_ms[market_id]
		var color_ids := colors.keys()
		color_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		for color: StringName in color_ids:
			entries.append({
				"market_id": String(market_id),
				"color": String(color),
				"saturated_until_ms": colors[color],
			})
	return entries


## The inverse of [method to_dict]. [param reader] reads the snapshot root.
## Records problems in it. Each saturation entry must
## name a known market and color, once, and must not have recovered by
## [param now_ms], because a tick forgets saturation that has recovered.
static func from_snapshot(reader: SnapshotReader, content: Content, now_ms: int) -> DemandState:
	var state := DemandState.new(reader.integer("drift_key", 0, _MASK32))
	for entry in reader.objects("saturation"):
		var market_id := entry.text_id("market_id")
		var color := entry.text_id("color")
		var until_ms := entry.integer("saturated_until_ms")
		if until_ms <= now_ms:
			entry.fail("saturated_until_ms", "must be after time_ms (%d)" % now_ms)
		if market_id != &"" and content.market(market_id) == null:
			entry.fail("market_id", "there is no market \"%s\"" % market_id)
			continue
		if color != &"" and content.color(color) == null:
			entry.fail("color", "there is no color \"%s\"" % color)
			continue
		if market_id == &"" or color == &"":
			continue
		if state._saturated_until_ms.has(market_id) and state._saturated_until_ms[market_id].has(color):
			entry.fail("color", "%s in %s has more than one saturation entry" % [color, market_id])
		if not state._saturated_until_ms.has(market_id):
			state._saturated_until_ms[market_id] = {}
		state._saturated_until_ms[market_id][color] = until_ms
	state._read_events(reader, content, now_ms)
	return state


## Reads the demand events and the time of the next one for
## [method from_snapshot]. The events must be in start order, and the next
## start must not be before [param now_ms], because a tick starts each event
## that is due.
func _read_events(reader: SnapshotReader, content: Content, now_ms: int) -> void:
	next_event_ms = reader.integer("next_demand_event_ms", UNSCHEDULED)
	if next_event_ms != UNSCHEDULED and next_event_ms < now_ms:
		reader.fail("next_demand_event_ms", "must be %d (no start set) or not before time_ms (%d)" % [
			UNSCHEDULED, now_ms])
	var last_start_ms := 0
	for entry in reader.objects("demand_events"):
		var event := DemandEventState.from_snapshot(entry, content, now_ms)
		if event == null:
			continue
		if event.started_at_ms < last_start_ms:
			entry.fail("started_at_ms", "the events must be in start order")
		last_start_ms = event.started_at_ms
		_events.append(event)


func _until_ms(market_id: StringName, color: StringName) -> int:
	var colors: Dictionary = _saturated_until_ms.get(market_id, {})
	return colors.get(color, 0)


## For [member _drift_cache]: [code][pair, knot, a, b][/code], with the
## values a and b of [param knot] and the knot after it, for
## [param market_id] and [param color].
func _knots(market_id: StringName, color: StringName, knot: int) -> Array:
	if not _drift_cache.has(market_id):
		_drift_cache[market_id] = {}
	var colors: Dictionary = _drift_cache[market_id]
	var entry: Array = colors.get(color, [])
	if entry.is_empty():
		entry = [_pair_hash(market_id, color), knot, 0.0, 0.0]
		entry[2] = _knot_value(entry[0], knot)
		entry[3] = _knot_value(entry[0], knot + 1)
		colors[color] = entry
	elif entry[1] != knot:
		var pair: int = entry[0]
		entry[2] = entry[3] if knot == entry[1] + 1 else _knot_value(pair, knot)
		entry[3] = _knot_value(pair, knot + 1)
		entry[1] = knot
	return entry


## The drift value of knot [param knot] for the market and color with
## [param pair]: a float in [0, 1). The value depends only on the key, the
## pair, and the knot, so any knot is known at any time.
func _knot_value(pair: int, knot: int) -> float:
	var rng := SimRng.new(((knot & _MASK32) << 32) | (pair ^ drift_key))
	# The first outputs of xoshiro128** come from only part of the seed, so
	# skip them until the knot index has an effect.
	for i in 3:
		rng.next_u32()
	return rng.randf()


## The pair hash of the forecast noise of [param market_id] and
## [param color]: a hash of other text than [method _pair_hash] hashes.
static func _forecast_pair_hash(market_id: StringName, color: StringName) -> int:
	return _pair_hash(StringName(_FORECAST_DOMAIN + "\n" + String(market_id)), color)


## A 32-bit FNV-1a hash of the market and color ids. We own it, because
## Godot's String.hash() can change between engine versions.
static func _pair_hash(market_id: StringName, color: StringName) -> int:
	var h := _FNV_OFFSET
	for byte in (String(market_id) + "\n" + String(color)).to_utf8_buffer():
		h = ((h ^ byte) * _FNV_PRIME) & _MASK32
	return h
