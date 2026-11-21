extends RefCounted
## Internal to the core. One demand event that has started and has not been
## forgotten yet. Code outside src/core reads it through DemandEventView.
##
## The state keeps the start and the end of the event. The name, the colors,
## the direction, and the size come from its [DemandEventDef].

const DemandEventState := preload("res://src/core/state/demand_event_state.gd")

var def: DemandEventDef
var started_at_ms: int
var ends_at_ms: int


func _init(p_def: DemandEventDef, p_started_at_ms: int, p_ends_at_ms: int) -> void:
	def = p_def
	started_at_ms = p_started_at_ms
	ends_at_ms = p_ends_at_ms


## True if the event changes demand at [param at_ms]: from its start, up to
## but not at its end.
func is_active_at(at_ms: int) -> bool:
	return started_at_ms <= at_ms and at_ms < ends_at_ms


func to_view(now_ms: int) -> DemandEventView:
	var view := DemandEventView.new()
	view.id = def.id
	view.name = def.name
	view.colors = def.colors
	view.direction = def.direction
	view.size = def.size
	view.factor = def.factor()
	view.started_at_ms = started_at_ms
	view.remaining_ms = ends_at_ms - now_ms
	return view


func to_dict() -> Dictionary:
	return {"event_id": String(def.id), "started_at_ms": started_at_ms, "ends_at_ms": ends_at_ms}


## The inverse of [method to_dict], or null when the event is not in
## [param content]. Records problems in [param reader]. The event must have
## started by [param now_ms] and must not have ended by then, because a tick
## forgets events that have ended.
static func from_snapshot(reader: SnapshotReader, content: Content, now_ms: int) -> DemandEventState:
	var event_id := reader.text_id("event_id")
	var started_at_ms := reader.integer("started_at_ms")
	var ends_at_ms := reader.integer("ends_at_ms")
	if started_at_ms > now_ms:
		reader.fail("started_at_ms", "must not be after time_ms (%d)" % now_ms)
	if ends_at_ms <= now_ms:
		reader.fail("ends_at_ms", "must be after time_ms (%d), because a tick forgets events that have ended" % now_ms)
	var def := content.demand_event(event_id)
	if def == null:
		if event_id != &"":
			reader.fail("event_id", "there is no demand event \"%s\"" % event_id)
		return null
	return DemandEventState.new(def, started_at_ms, ends_at_ms)
