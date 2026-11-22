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

## The value of [member saved_at_unix_ms] for a save older than
## [constant SaveCodec.SAVE_TIME_VERSION], which has no save time.
const NO_SAVE_TIME := -1

var ok: bool
var reason: Reason
## Text for the player or a log. Do not branch on it; use [member reason].
var message: String
## True when the load ran at least one migration. A failed load that migrated
## can mean that the migrations cannot read an old save.
var migrated: bool
## The loaded simulation, or null when the load failed.
var simulation: Simulation
## The device clock time that the saved state is for, in Unix milliseconds, or
## [constant NO_SAVE_TIME].
var saved_at_unix_ms: int = NO_SAVE_TIME


static func success(p_simulation: Simulation, p_saved_at_unix_ms: int) -> LoadResult:
	var result := LoadResult.new()
	result.ok = true
	result.reason = Reason.NONE
	result.simulation = p_simulation
	result.saved_at_unix_ms = p_saved_at_unix_ms
	return result


## The time away from the save time to [param now_unix_ms], for offline
## progress. 0 when the save has no save time or when the clock went backward,
## so that a clock change cannot take progress away or give it twice.
func time_away_ms(now_unix_ms: int) -> int:
	if not ok or saved_at_unix_ms == NO_SAVE_TIME:
		return 0
	return maxi(now_unix_ms - saved_at_unix_ms, 0)


static func failure(p_reason: Reason, p_message: String) -> LoadResult:
	var result := LoadResult.new()
	result.ok = false
	result.reason = p_reason
	result.message = p_message
	return result
