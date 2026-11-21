extends GutTest
## The export code: the save as a code that the player copies to another
## device (see ADR-0010).

## The save time of the saves that the tests write: a time in November 2026.
const SAVED_AT_UNIX_MS := 1_795_000_000_000


## A game with factories, production lines, links, and shipments in transit.
func _game() -> Simulation:
	var sim := Simulation.new(ContentFixture.make_mixed(700, 6), 77)
	sim.build_factory(&"red")
	sim.tick(1234)
	sim.build_factory(&"blue")
	sim.add_production_line(2)
	sim.make_link(1, &"millbrook")
	sim.tick(5000)
	sim.start_shipment(1)
	sim.tick(333)
	return sim


func _import(code: String, steps: Array[Callable] = SaveCodec.migrations(),
		content: Content = ContentFixture.make_mixed(700, 6)) -> LoadResult:
	return ExportCode.decode(content, code, steps)


func test_export_then_import_gives_the_same_state() -> void:
	var sim := _game()

	var result := _import(ExportCode.encode(sim, SAVED_AT_UNIX_MS))

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.snapshot(), sim.snapshot())
	assert_eq(result.simulation.link(1).shipments_in_transit.size(), 1)


func test_the_code_holds_the_same_save_as_the_device() -> void:
	var sim := _game()
	var code := ExportCode.encode(sim, SAVED_AT_UNIX_MS)
	var compressed := Marshalls.base64_to_raw(code.split(".")[1])

	var save_text := compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE).get_string_from_utf8()

	assert_eq(save_text, SaveCodec.encode(sim, SAVED_AT_UNIX_MS))


func test_the_code_has_a_version_and_a_checksum() -> void:
	var code := ExportCode.encode(_game(), SAVED_AT_UNIX_MS)
	var parts := code.split(".")

	assert_eq(parts.size(), 3)
	assert_eq(parts[0], "IR%d" % SaveCodec.current_version())
	assert_eq(parts[2].length(), ExportCode.CHECKSUM_LENGTH)
	assert_eq(parts[2], (parts[0] + "." + parts[1]).sha256_text().substr(0, ExportCode.CHECKSUM_LENGTH))


func test_spaces_and_line_breaks_in_the_code_do_not_matter() -> void:
	var sim := _game()
	var code := ExportCode.encode(sim, SAVED_AT_UNIX_MS)
	var wrapped := "  %s\n%s \r\n\t%s  " % [code.substr(0, 10), code.substr(10, 30), code.substr(40)]

	var result := _import(wrapped)

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.snapshot(), sim.snapshot())


# --- Bad codes ------------------------------------------------------------------

## Imports [param code] and checks that it fails with [param reason] and a
## message that has [param message_part], and that the current game does not
## change.
func _assert_import_fails(code: String, reason: LoadResult.Reason, message_part: String,
		steps: Array[Callable] = SaveCodec.migrations()) -> void:
	var current := _game()
	var before := current.snapshot()

	var result := _import(code, steps)

	assert_false(result.ok, "the import fails")
	assert_eq(result.reason, reason, result.message)
	assert_string_contains(result.message, message_part)
	assert_null(result.simulation)
	assert_eq(current.snapshot(), before, "the current game does not change")


## [param code] with the character at [param index] changed to another one of
## the base64 alphabet. The new character also differs when case is ignored,
## because the checksum check ignores case.
func _with_changed_character(code: String, index: int) -> String:
	var changed := "B" if code[index].to_upper() == "A" else "A"
	return code.substr(0, index) + changed + code.substr(index + 1)


func test_a_code_with_a_changed_character_fails_its_checksum() -> void:
	var code := ExportCode.encode(_game(), SAVED_AT_UNIX_MS)
	var index := code.find(".") + 20

	_assert_import_fails(_with_changed_character(code, index), LoadResult.Reason.BAD_CHECKSUM,
		"checksum does not match")


func test_a_code_with_a_changed_checksum_fails() -> void:
	var code := ExportCode.encode(_game(), SAVED_AT_UNIX_MS)

	_assert_import_fails(_with_changed_character(code, code.length() - 1), LoadResult.Reason.BAD_CHECKSUM,
		"checksum does not match")


func test_a_code_that_is_cut_off_fails_its_checksum() -> void:
	var code := ExportCode.encode(_game(), SAVED_AT_UNIX_MS)
	var last_dot := code.rfind(".")
	var cut := code.substr(0, last_dot - 12) + code.substr(last_dot)

	_assert_import_fails(cut, LoadResult.Reason.BAD_CHECKSUM, "checksum does not match")


func test_a_code_with_a_changed_version_fails_its_checksum() -> void:
	var code := ExportCode.encode(_game(), SAVED_AT_UNIX_MS)
	var changed := code.replace("IR%d." % SaveCodec.current_version(), "IR1.")

	_assert_import_fails(changed, LoadResult.Reason.BAD_CHECKSUM, "checksum does not match")


func test_text_that_is_not_a_code_fails() -> void:
	_assert_import_fails("", LoadResult.Reason.NOT_A_CODE, "not an export code")
	_assert_import_fails("hello", LoadResult.Reason.NOT_A_CODE, "not an export code")
	_assert_import_fails(SaveCodec.encode(_game(), SAVED_AT_UNIX_MS), LoadResult.Reason.NOT_A_CODE, "not an export code")
	_assert_import_fails("XY2.abc.12345678", LoadResult.Reason.NOT_A_CODE, "not an export code")


## A code made of [param body] with a correct checksum, for damage that the
## checksum cannot find.
func _signed(body: String) -> String:
	return body + "." + body.sha256_text().substr(0, ExportCode.CHECKSUM_LENGTH)


func test_a_code_with_no_valid_version_fails() -> void:
	var payload := ExportCode.encode(_game(), SAVED_AT_UNIX_MS).split(".")[1]

	_assert_import_fails(_signed("IR." + payload), LoadResult.Reason.BAD_VERSION, "no valid version")
	_assert_import_fails(_signed("IR0." + payload), LoadResult.Reason.BAD_VERSION, "no valid version")
	_assert_import_fails(_signed("IRtwo." + payload), LoadResult.Reason.BAD_VERSION, "no valid version")


func test_a_code_with_a_payload_that_is_not_compressed_fails() -> void:
	var payload := Marshalls.utf8_to_base64(SaveCodec.encode(_game(), SAVED_AT_UNIX_MS))

	_assert_import_fails(_signed("IR%d.%s" % [SaveCodec.current_version(), payload]),
		LoadResult.Reason.NOT_A_CODE, "its save cannot be read")
	assert_engine_error("incorrect header check")
	assert_engine_error("Method/function failed")


func test_a_code_of_a_save_too_large_to_import_fails() -> void:
	var huge := PackedByteArray()
	huge.resize(ExportCode.MAX_SAVE_BYTES + 1)
	huge.fill(32)
	var payload := Marshalls.raw_to_base64(huge.compress(FileAccess.COMPRESSION_DEFLATE))

	_assert_import_fails(_signed("IR%d.%s" % [SaveCodec.current_version(), payload]),
		LoadResult.Reason.NOT_A_CODE, "its save cannot be read")
	assert_engine_error("Method/function failed")


func test_a_code_with_a_payload_that_is_not_base64_fails() -> void:
	for payload in ["!!!!", "abc", "ab=c", "===="]:
		_assert_import_fails(_signed("IR%d.%s" % [SaveCodec.current_version(), payload]),
			LoadResult.Reason.NOT_A_CODE, "its save cannot be read")


func test_a_code_of_text_that_is_not_a_save_fails() -> void:
	_assert_import_fails(ExportCode.from_save("[1, 2, 3]", SaveCodec.current_version()),
		LoadResult.Reason.NOT_A_SAVE, "not a save")


func test_a_code_of_a_damaged_save_fails() -> void:
	var data: Dictionary = JSON.parse_string(SaveCodec.encode(_game(), SAVED_AT_UNIX_MS))
	data.state.factories[0].color = "magenta"

	_assert_import_fails(ExportCode.from_save(JSON.stringify(data), SaveCodec.current_version()),
		LoadResult.Reason.DAMAGED_STATE, "state.factories[0].color: there is no color \"magenta\"")


# --- Versions -------------------------------------------------------------------

func test_a_code_from_a_newer_game_fails() -> void:
	var data: Dictionary = JSON.parse_string(SaveCodec.encode(_game(), SAVED_AT_UNIX_MS))
	var newer := SaveCodec.current_version() + 1
	data.version = newer

	_assert_import_fails(ExportCode.from_save(JSON.stringify(data), newer), LoadResult.Reason.NEWER_VERSION,
		"A newer version of the game made this export code (save version %d)" % newer)
	_assert_import_fails(ExportCode.from_save(JSON.stringify(data), newer), LoadResult.Reason.NEWER_VERSION,
		"Update the game")


## A test migration: in its version 1, the state named time "clock_ms".
static func _rename_clock(state: Dictionary) -> Dictionary:
	state.time_ms = state.get("clock_ms")
	state.erase("clock_ms")
	return state


## A test migration that cannot turn a version 1 state into version 2.
static func _lose_time(state: Dictionary) -> Dictionary:
	state.erase("clock_ms")
	return state


## The code of a version 1 save in which time is named "clock_ms".
func _version_1_code() -> String:
	var state: Dictionary = JSON.parse_string(SaveCodec.encode(_game(), SAVED_AT_UNIX_MS)).state
	state.clock_ms = state.time_ms
	state.erase("time_ms")
	return ExportCode.from_save(JSON.stringify({"format": SaveCodec.FORMAT, "version": 1, "state": state}), 1)


func test_a_code_of_an_older_version_migrates() -> void:
	var steps: Array[Callable] = [_rename_clock]

	var result := _import(_version_1_code(), steps)

	assert_true(result.ok, result.message)
	assert_eq(result.simulation.snapshot(), _game().snapshot())


func test_a_code_of_an_older_version_that_cannot_migrate_fails() -> void:
	var steps: Array[Callable] = [_lose_time]

	_assert_import_fails(_version_1_code(), LoadResult.Reason.DAMAGED_STATE,
		"from an older version of the game (save version 1), and this version cannot read it", steps)
	_assert_import_fails(_version_1_code(), LoadResult.Reason.DAMAGED_STATE, "state.time_ms: is missing", steps)


## The save of each version in tests/fixtures/saves/ imports as a code, with the
## same migrations as the save on the device.
func test_each_saved_version_imports_as_a_code() -> void:
	var dir := "res://tests/fixtures/saves/"
	var files := DirAccess.get_files_at(dir)
	assert_gt(files.size(), 0)
	for file in files:
		var save_text := FileAccess.get_file_as_string(dir + file)
		var version := int(JSON.parse_string(save_text).version)

		var from_file := SaveCodec.decode(ContentFixture.make_for_saves(), save_text)
		var from_code := _import(ExportCode.from_save(save_text, version), SaveCodec.migrations(),
			ContentFixture.make_for_saves())

		assert_true(from_code.ok, "%s: %s" % [file, from_code.message])
		if from_code.ok and from_file.ok:
			assert_eq(from_code.simulation.snapshot(), from_file.simulation.snapshot(), file)


func test_the_export_code_keeps_the_save_time() -> void:
	var result := _import(ExportCode.encode(_game(), SAVED_AT_UNIX_MS))

	assert_true(result.ok, result.message)
	assert_eq(result.saved_at_unix_ms, SAVED_AT_UNIX_MS)
