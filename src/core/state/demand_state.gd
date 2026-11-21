extends RefCounted
## Internal to the core. The demand of each color in each market, from drift
## and saturation. Code outside src/core reads demand through MarketView.
## See ADR-0011.
##
## Demand is drift times saturation, and the price is the base price times
## demand. 1 is normal demand.
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

const DemandState := preload("res://src/core/state/demand_state.gd")

const _MASK32 := 0xFFFFFFFF
const _FNV_OFFSET := 0x811C9DC5
const _FNV_PRIME := 0x01000193

## The u32 that seeds drift. It does not change during a game.
var drift_key: int
## Market id to color id to the time when saturation of that color in that
## market has fully recovered. Only colors with saturation now are here.
var _saturated_until_ms: Dictionary[StringName, Dictionary] = {}


func _init(p_drift_key: int) -> void:
	drift_key = p_drift_key & _MASK32


## The demand of [param color] in [param market_id] at [param at_ms].
func demand(market_id: StringName, color: StringName, at_ms: int, balance: DemandBalance) -> float:
	return drift(market_id, color, at_ms, balance) * saturation_factor(market_id, color, at_ms, balance)


## The drift part of demand: from 1 - amplitude to 1 + amplitude.
func drift(market_id: StringName, color: StringName, at_ms: int, balance: DemandBalance) -> float:
	if balance.drift_amplitude == 0.0:
		return 1.0
	var pair := _pair_hash(market_id, color)
	@warning_ignore("integer_division")
	var knot := at_ms / balance.drift_period_ms
	var t := float(at_ms - knot * balance.drift_period_ms) / balance.drift_period_ms
	var smooth := t * t * (3.0 - 2.0 * t)
	var value := lerpf(_knot_value(pair, knot), _knot_value(pair, knot + 1), smooth)
	return 1.0 + balance.drift_amplitude * (2.0 * value - 1.0)


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


## Forgets saturation that has fully recovered by [param now_ms], so that the
## state holds only saturation that has an effect.
func prune(now_ms: int) -> void:
	for market_id in _saturated_until_ms.keys():
		var colors: Dictionary = _saturated_until_ms[market_id]
		for color: StringName in colors.keys():
			if colors[color] <= now_ms:
				colors.erase(color)
		if colors.is_empty():
			_saturated_until_ms.erase(market_id)


## The saturation as plain data, sorted by market and color, so that equal
## states give equal snapshots.
func saturation_to_list() -> Array[Dictionary]:
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


## The inverse of [member drift_key] and [method saturation_to_list] in a
## snapshot. Records problems in [param reader]. Each saturation entry must
## name a known market and color, once, and must not have recovered by
## [param now_ms], because a tick forgets saturation that has recovered.
static func from_snapshot(reader: SnapshotReader, content: Content, now_ms: int) -> DemandState:
	var state := DemandState.new(reader.integer("drift_key", 0, _MASK32))
	for entry in reader.objects("saturation"):
		var market_id := entry.text_id("market_id")
		var color := entry.text_id("color")
		var until_ms := entry.integer("saturated_until_ms")
		if market_id != &"" and content.market(market_id) == null:
			entry.fail("market_id", "there is no market \"%s\"" % market_id)
		if color != &"" and content.color(color) == null:
			entry.fail("color", "there is no color \"%s\"" % color)
		if state._saturated_until_ms.has(market_id) and state._saturated_until_ms[market_id].has(color):
			entry.fail("color", "%s in %s has more than one saturation entry" % [color, market_id])
		if until_ms <= now_ms:
			entry.fail("saturated_until_ms", "must be after time_ms (%d)" % now_ms)
		if not state._saturated_until_ms.has(market_id):
			state._saturated_until_ms[market_id] = {}
		state._saturated_until_ms[market_id][color] = until_ms
	return state


func _until_ms(market_id: StringName, color: StringName) -> int:
	var colors: Dictionary = _saturated_until_ms.get(market_id, {})
	return colors.get(color, 0)


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


## A 32-bit FNV-1a hash of the market and color ids. We own it, because
## Godot's String.hash() can change between engine versions.
static func _pair_hash(market_id: StringName, color: StringName) -> int:
	var h := _FNV_OFFSET
	for byte in (String(market_id) + "\n" + String(color)).to_utf8_buffer():
		h = ((h ^ byte) * _FNV_PRIME) & _MASK32
	return h
