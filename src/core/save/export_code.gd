class_name ExportCode
extends RefCounted
## Turns the save into a code that the player can copy to another device, and
## back. See ADR-0010.
##
## A code is the save text of [method SaveCodec.encode], compressed, in base64,
## with a version and a checksum:
## [code]IR<version>.<base64 of the deflated save text>.<checksum>[/code].
## The version is the save format version, [constant SaveCodec.VERSION]. The
## checksum is the first [constant CHECKSUM_LENGTH] hex digits of the SHA-256
## of all the text before the last dot, so a code that a typo or a cut damages
## fails before it loads.
##
## An import makes a new [Simulation] through [method SaveCodec.decode], with
## the same migrations as a save on the device, and never changes the current
## game.

const PREFIX := "IR"
const SEPARATOR := "."
const CHECKSUM_LENGTH := 8
## The largest save text that an import decompresses, so that a hostile code
## cannot use all the memory of the device.
const MAX_SAVE_BYTES := 16 * 1024 * 1024
const UPDATE_THE_GAME := "Update the game, then import the code again."


## The export code of the current state of [param sim], which is the state at
## the device clock time [param saved_at_unix_ms]. An import gives offline
## progress from that time, as a save on the device does.
static func encode(sim: Simulation, saved_at_unix_ms: int) -> String:
	return from_save(SaveCodec.encode(sim, saved_at_unix_ms), SaveCodec.VERSION)


## The export code of [param save_text], a save of version [param version].
## [method encode] is the entry point for the game; this one is for tests that
## need a code of another version.
static func from_save(save_text: String, version: int) -> String:
	var compressed := save_text.to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var body := "%s%d%s%s" % [PREFIX, version, SEPARATOR, Marshalls.raw_to_base64(compressed)]
	return body + SEPARATOR + _checksum(body)


## Loads [param code] into a new simulation with [param content]. Spaces and
## line breaks in the code do not matter, because a messaging app can add them.
## [param migrations] is for tests; the game uses the default.
static func decode(content: Content, code: String,
		migrations: SaveMigrations = SaveMigrations.found()) -> LoadResult:
	var text := _without_whitespace(code)
	var parts := text.split(SEPARATOR)
	if parts.size() != 3 or not parts[0].begins_with(PREFIX):
		return _not_a_code("This is not an export code of Incremental Rainbow.")
	var body := parts[0] + SEPARATOR + parts[1]
	if parts[2].to_lower() != _checksum(body):
		return LoadResult.failure(LoadResult.Reason.BAD_CHECKSUM,
			"The export code is damaged: its checksum does not match. Copy the whole code again.")

	var version_text := parts[0].substr(PREFIX.length())
	if not version_text.is_valid_int() or version_text.to_int() < 1:
		return LoadResult.failure(LoadResult.Reason.BAD_VERSION, "The export code is damaged: it has no valid version.")
	var version := version_text.to_int()
	if version > SaveCodec.VERSION:
		return LoadResult.failure(LoadResult.Reason.NEWER_VERSION,
			"A newer version of the game made this export code (save version %d). This version reads codes up to version %d. %s" % [
				version, SaveCodec.VERSION, UPDATE_THE_GAME])

	var save_bytes := PackedByteArray()
	if _is_base64(parts[1]):
		# Data that is not deflate data, or that is too large, makes the engine
		# log an error. Only a code that someone made by hand can have it,
		# because the checksum matches.
		save_bytes = Marshalls.base64_to_raw(parts[1]).decompress_dynamic(
			MAX_SAVE_BYTES, FileAccess.COMPRESSION_DEFLATE)
	if save_bytes.is_empty():
		return _not_a_code("The export code is damaged: its save cannot be read.")
	var save_text := save_bytes.get_string_from_utf8()

	var result := SaveCodec.decode(content, save_text, migrations)
	if result.reason == LoadResult.Reason.NEWER_VERSION:
		# The version of the code does not change for each change to the
		# state, so a code of a newer game can have the same version.
		result.message = "%s %s" % [
			result.message.replace(SaveCodec.NEWER_SAVE,
			"A newer version of the game made this export code"), UPDATE_THE_GAME]
	elif result.reason == LoadResult.Reason.DAMAGED_STATE and result.migrated:
		result.message = "This export code is from an older version of the game, and this version cannot read it. %s" % [
			result.message]
	return result


static func _checksum(body: String) -> String:
	return body.sha256_text().substr(0, CHECKSUM_LENGTH)


## True when [param text] is base64 that [method Marshalls.base64_to_raw]
## reads with no error.
static func _is_base64(text: String) -> bool:
	if text.is_empty() or text.length() % 4 != 0:
		return false
	var regex := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	return regex.search(text) != null


static func _without_whitespace(code: String) -> String:
	var kept := PackedStringArray()
	for character in code:
		if not character in [" ", "\t", "\n", "\r"]:
			kept.append(character)
	return "".join(kept)


static func _not_a_code(message: String) -> LoadResult:
	return LoadResult.failure(LoadResult.Reason.NOT_A_CODE, message)
