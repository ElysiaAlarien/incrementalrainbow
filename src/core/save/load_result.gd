class_name LoadResult
extends RefCounted
## The result of [method SaveCodec.decode] and [method ExportCode.decode]: a
## new [Simulation], or the reason the save cannot load. A failed load makes no
## simulation, so it cannot change the current game.

enum Reason {
	NONE,
	## The text is not valid JSON, for example a save that was cut off.
	NOT_JSON,
	## The JSON is not a save of this game.
	NOT_A_SAVE,
	## The save or the export code has no valid version number.
	BAD_VERSION,
	## A newer version of the game wrote the save, so this version cannot read it.
	NEWER_VERSION,
	## The core state in the save is missing a value or has a value that is
	## not allowed.
	DAMAGED_STATE,
	## The text is not an export code, or its save cannot be read.
	NOT_A_CODE,
	## The checksum of the export code does not match, for example a code that
	## was cut off or has a typo.
	BAD_CHECKSUM,
}

var ok: bool
var reason: Reason
## Text for the player or a log. Do not branch on it; use [member reason].
var message: String
## The loaded simulation, or null when the load failed.
var simulation: Simulation


static func success(p_simulation: Simulation) -> LoadResult:
	var result := LoadResult.new()
	result.ok = true
	result.reason = Reason.NONE
	result.simulation = p_simulation
	return result


static func failure(p_reason: Reason, p_message: String) -> LoadResult:
	var result := LoadResult.new()
	result.ok = false
	result.reason = p_reason
	result.message = p_message
	return result
