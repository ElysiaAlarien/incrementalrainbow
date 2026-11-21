class_name DemandBalance
extends RefCounted
## Balance values for demand, drift, saturation, and demand events, from
## balance.json.
## Read-only. All values are placeholders until playtests set them.

## Time between two drift knots. Drift moves smoothly from one knot to the next.
var drift_period_ms: int:
	get:
		return _drift_period_ms
## The largest change that drift makes to demand, as a fraction of demand 1.
## 0 gives no drift, and 0.3 gives demand from 0.7 to 1.3.
var drift_amplitude: float:
	get:
		return _drift_amplitude
## The time that saturation from one sold widget takes to recover. 0 gives no
## saturation.
var saturation_ms_per_widget: int:
	get:
		return _saturation_ms_per_widget
## The count of recent widgets that halves demand by saturation.
var saturation_half_widgets: float:
	get:
		return _saturation_half_widgets

## The shortest and the longest time from the start of one demand event to
## the start of the next. Each time is a random whole number of milliseconds
## in this range, with both ends included.
var event_interval_min_ms: int:
	get:
		return _event_interval_min_ms
var event_interval_max_ms: int:
	get:
		return _event_interval_max_ms

var _drift_period_ms: int
var _drift_amplitude: float
var _saturation_ms_per_widget: int
var _saturation_half_widgets: float
var _event_interval_min_ms: int
var _event_interval_max_ms: int


func _init(p_drift_period_ms: int, p_drift_amplitude: float,
		p_saturation_ms_per_widget: int, p_saturation_half_widgets: float,
		p_event_interval_min_ms: int, p_event_interval_max_ms: int) -> void:
	_drift_period_ms = p_drift_period_ms
	_drift_amplitude = p_drift_amplitude
	_saturation_ms_per_widget = p_saturation_ms_per_widget
	_saturation_half_widgets = p_saturation_half_widgets
	_event_interval_min_ms = p_event_interval_min_ms
	_event_interval_max_ms = p_event_interval_max_ms
