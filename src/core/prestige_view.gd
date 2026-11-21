class_name PrestigeView
extends RefCounted
## A read-only copy of what a prestige does now, returned by
## [method Simulation.prestige_preview]. Changing it does not change the
## simulation.

## True if [method Simulation.prestige] is allowed now.
var allowed: bool
## Why a prestige is not allowed now, for the player. Empty when
## [member allowed] is true.
var message: String
## What a prestige keeps, as names for the player, such as "Prisms".
var keeps: PackedStringArray
## What a prestige clears to a fresh run, as names for the player, such as
## "Money".
var clears: PackedStringArray
