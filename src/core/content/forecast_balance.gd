class_name ForecastBalance
extends RefCounted
## Balance values for the forecast, from balance.json.
## Read-only. All values are placeholders until playtests set them.

## The forecast accuracy with no forecast research, from 0 to 1. A small value
## makes the forecast nearly random at the start of a run.
var base_accuracy: float:
	get:
		return _base_accuracy
## The time ahead of now that the screen shows the forecast for.
var horizon_ms: int:
	get:
		return _horizon_ms

var _base_accuracy: float
var _horizon_ms: int


func _init(p_base_accuracy: float, p_horizon_ms: int) -> void:
	_base_accuracy = p_base_accuracy
	_horizon_ms = p_horizon_ms
