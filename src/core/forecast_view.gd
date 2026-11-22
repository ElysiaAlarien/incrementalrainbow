class_name ForecastView
extends RefCounted
## A read-only copy of the forecast, returned by [method Simulation.forecast].
## Changing it does not change the simulation.
##
## The forecast of a color in a market is its demand at [member at_ms] if the
## player sells nothing more there and no other demand event starts. Drift is
## the part of demand that the player cannot see yet, so the forecast mixes the
## real drift with forecast noise: by [member accuracy] of the real drift and
## the rest of noise. Saturation and the demand events that have started are
## known, so the forecast has them as they will be at [member at_ms].

## The time that the forecast is for: the time of the query plus
## [member ahead_ms].
var at_ms: int
## How far ahead of the time of the query the forecast is.
var ahead_ms: int
## How accurate the forecast is, from 0 (the drift part is noise) to 1 (it
## is the real drift).
var accuracy: float
## Market id to color id to the forecast of the demand of that color there.
var demands: Dictionary[StringName, Dictionary] = {}


## The forecast of the demand of [param color] in [param market_id], or NAN
## for an unknown market or color.
func demand(market_id: StringName, color: StringName) -> float:
	var colors: Dictionary = demands.get(market_id, {})
	return colors.get(color, NAN)
