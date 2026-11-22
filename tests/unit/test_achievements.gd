extends GutTest
## Platform achievements (#25, ADR-0019): the achievement data, and the tracker
## that unlocks achievements from the milestones of the core through the test
## adapter.

const SEED := 25


## Content with mixed colors, research, and 10000 money at the start.
func _content() -> Content:
	return ContentFixture.from_data(ContentFixture.data(ContentFixture.mixed_colors_data(),
		ContentFixture.balance_data(1000, 10, {"starting_money": 10_000})))


## The data of an achievement, with each value of [param overrides].
func _entry(id: String, milestone: String, overrides: Dictionary = {}) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "description": "Do %s." % id,
		"milestone": milestone}.merged(overrides, true)


func _list(entries: Array) -> AchievementList:
	return AchievementList.from_data({"achievements": entries}, _content())


## A list with the first sale, two prisms, and the first prestige.
func _sample_list() -> AchievementList:
	var list := _list([
		_entry("first_sale", "first_sale"),
		_entry("two_prisms", "prisms_bought", {"at_least": 2}),
		_entry("first_prestige", "prestiges"),
	])
	assert_eq(list.errors, PackedStringArray())
	return list


func _ok(result: CommandResult) -> Variant:
	assert_true(result.ok, result.message)
	return result.value


## A red factory with a link to the market, and one shipment that sells.
func _sell_once(sim: Simulation) -> void:
	var factory: int = _ok(sim.build_factory(&"red"))
	var link: int = _ok(sim.make_link(factory, &"millbrook"))
	sim.tick(2000)
	_ok(sim.start_shipment(link))
	sim.tick(ContentFixture.TRANSIT_TIME_MS)


# --- The data -----------------------------------------------------------------

func test_the_game_data_loads_with_no_errors() -> void:
	var content := Content.load_dir(Content.DEFAULT_DIR)
	var list := AchievementList.load_file(AchievementList.DEFAULT_PATH, content)

	assert_eq(list.errors, PackedStringArray())
	assert_gt(list.all().size(), 0)


func test_the_game_data_has_the_samples_of_the_issue() -> void:
	var list := AchievementList.load_file(AchievementList.DEFAULT_PATH, Content.load_dir(Content.DEFAULT_DIR))
	var granted := {}
	for def in list.all():
		granted[[def.milestone, def.at_least]] = true

	assert_true(granted.has([Milestones.FIRST_SALE, 1]), "the first sale")
	assert_true(granted.has([Milestones.PRISMS_BOUGHT, 1]), "the first prism")
	assert_true(granted.has([Milestones.PRESTIGES, 1]), "the first prestige")


func test_each_achievement_of_the_game_data_has_a_steam_and_a_game_center_id() -> void:
	var list := AchievementList.load_file(AchievementList.DEFAULT_PATH, Content.load_dir(Content.DEFAULT_DIR))

	for def in list.all():
		assert_false(def.platform_id(&"steam").is_empty(), String(def.id))
		assert_false(def.platform_id(&"game_center").is_empty(), String(def.id))


func test_an_achievement_has_its_values() -> void:
	var list := _list([_entry("two_prisms", "prisms_bought", {"at_least": 2,
		"platform_ids": {"steam": "TWO_PRISMS", "google_play": ""}})])

	var def := list.all()[0]
	assert_eq([def.id, def.name, def.description, def.milestone, def.at_least],
		[&"two_prisms", "Two Prisms", "Do two_prisms.", &"prisms_bought", 2])
	assert_eq(def.platform_id(&"steam"), "TWO_PRISMS")
	assert_eq(def.platform_id(&"google_play"), "", "an empty id is no id")
	assert_eq(def.platform_id(&"game_center"), "")
	assert_eq(list.for_milestone(&"prisms_bought"), [def] as Array[AchievementDef])


func test_bad_data_reports_each_problem_and_gives_no_achievements() -> void:
	var cases := {
		"a list": {"achievements": {}},
		"an object": {"achievements": ["first_sale"]},
		"no id": {"achievements": [_entry("", "first_sale")]},
		"duplicate achievement id": {"achievements": [_entry("a", "first_sale"), _entry("a", "prestiges")]},
		"has no name": {"achievements": [_entry("a", "first_sale", {"name": ""})]},
		"has no description": {"achievements": [_entry("a", "first_sale", {"description": 3})]},
		"the game does not have": {"achievements": [_entry("a", "dance")]},
		"positive integer": {"achievements": [_entry("a", "prestiges", {"at_least": 0.5})]},
		"is not a count": {"achievements": [_entry("a", "first_sale", {"at_least": 2})]},
		"must be an object": {"achievements": [_entry("a", "first_sale", {"platform_ids": []})]},
		"platform \"xbox\"": {"achievements": [_entry("a", "first_sale", {"platform_ids": {"xbox": "A"}})]},
		"must be text": {"achievements": [_entry("a", "first_sale", {"platform_ids": {"steam": 1}})]},
		"the same steam id": {"achievements": [
			_entry("a", "first_sale", {"platform_ids": {"steam": "A"}}),
			_entry("b", "prestiges", {"platform_ids": {"steam": "A"}})]},
	}
	for problem: String in cases:
		var list := AchievementList.from_data(cases[problem], _content())

		assert_eq(list.errors.size(), 1, problem)
		if list.errors.size() == 1:
			assert_string_contains(list.errors[0], problem)
		assert_eq(list.all(), [] as Array[AchievementDef], problem)


func test_a_file_that_is_not_there_is_an_error() -> void:
	var list := AchievementList.load_file("res://no_such_file.json", _content())

	assert_eq(list.errors.size(), 1)
	assert_string_contains(list.errors[0], "file not found")


# --- The tracker --------------------------------------------------------------

func test_the_first_sale_unlocks_its_achievement() -> void:
	var service := TestAchievementService.new()
	var tracker := AchievementTracker.new(_sample_list(), service)
	var sim := Simulation.new(_content(), SEED)
	tracker.attach(sim)
	assert_eq(service.unlocked, [] as Array[StringName], "a new game has no achievements")

	_sell_once(sim)

	assert_eq(service.unlocked, [&"first_sale"] as Array[StringName])


func test_a_count_unlocks_at_its_value() -> void:
	var service := TestAchievementService.new()
	var tracker := AchievementTracker.new(_sample_list(), service)
	var sim := Simulation.new(_content(), SEED)
	tracker.attach(sim)

	_ok(sim.buy_prism())
	assert_eq(service.unlocked, [] as Array[StringName])
	_ok(sim.buy_prism())
	assert_eq(service.unlocked, [&"two_prisms"] as Array[StringName])
	_ok(sim.prestige())
	assert_eq(service.unlocked, [&"two_prisms", &"first_prestige"] as Array[StringName])


func test_attach_unlocks_what_the_milestones_grant_already() -> void:
	# Play from before the tracker listened, such as a loaded save.
	var sim := Simulation.new(_content(), SEED)
	_sell_once(sim)
	_ok(sim.buy_prism())
	_ok(sim.prestige())
	var service := TestAchievementService.new()
	var tracker := AchievementTracker.new(_sample_list(), service)

	tracker.attach(sim)

	assert_eq(service.unlocked, [&"first_sale", &"first_prestige"] as Array[StringName])


func test_a_loaded_save_unlocks_its_achievements() -> void:
	var played := Simulation.new(_content(), SEED)
	_sell_once(played)
	var loaded := SaveCodec.decode(_content(), SaveCodec.encode(played, 0))
	assert_true(loaded.ok, loaded.message)
	var service := TestAchievementService.new()

	AchievementTracker.new(_sample_list(), service).attach(loaded.simulation)

	assert_eq(service.unlocked, [&"first_sale"] as Array[StringName])


# --- Imported export codes (ADR-0019) ------------------------------------------

## A list with the first sale, the first prism, and two prisms.
func _prism_list() -> AchievementList:
	var list := _list([
		_entry("first_sale", "first_sale"),
		_entry("first_prism", "prisms_bought"),
		_entry("two_prisms", "prisms_bought", {"at_least": 2}),
	])
	assert_eq(list.errors, PackedStringArray())
	return list


## A game of another player with a sale and one prism, as the screen has it
## after an import of its code.
func _imported_game() -> Simulation:
	var other := Simulation.new(_content(), SEED)
	_sell_once(other)
	_ok(other.buy_prism())
	var imported := SaveCodec.decode(_content(), SaveCodec.encode(other, 0))
	assert_true(imported.ok, imported.message)
	_ok(imported.simulation.mark_milestones_imported())
	return imported.simulation


func test_an_imported_game_unlocks_nothing() -> void:
	var service := TestAchievementService.new()

	AchievementTracker.new(_prism_list(), service).attach(_imported_game())

	assert_eq(service.unlocked, [] as Array[StringName])


func test_an_imported_game_unlocks_nothing_after_a_restart() -> void:
	var restarted := SaveCodec.decode(_content(), SaveCodec.encode(_imported_game(), 0))
	assert_true(restarted.ok, restarted.message)
	var service := TestAchievementService.new()

	AchievementTracker.new(_prism_list(), service).attach(restarted.simulation)

	assert_eq(service.unlocked, [] as Array[StringName])


func test_after_an_import_only_a_value_that_the_import_did_not_have_unlocks() -> void:
	var sim := _imported_game()
	var service := TestAchievementService.new()
	var tracker := AchievementTracker.new(_prism_list(), service)
	tracker.attach(sim)

	_sell_once(sim)
	assert_eq(service.unlocked, [] as Array[StringName], "the import had the first sale")
	_ok(sim.buy_prism())
	assert_eq(service.unlocked, [&"two_prisms"] as Array[StringName], "the import had one prism")

	var restarted := SaveCodec.decode(_content(), SaveCodec.encode(sim, 0))
	var after_restart := TestAchievementService.new()
	AchievementTracker.new(_prism_list(), after_restart).attach(restarted.simulation)
	assert_eq(after_restart.unlocked, [&"two_prisms"] as Array[StringName], "the same at the next start")


func test_a_cloud_save_of_the_players_own_game_unlocks_its_achievements() -> void:
	# A load from the cloud save does not mark an import.
	var own := Simulation.new(_content(), SEED)
	_sell_once(own)
	_ok(own.buy_prism())
	var from_cloud := ExportCode.decode(_content(), ExportCode.encode(own, 0))
	assert_true(from_cloud.ok, from_cloud.message)
	var service := TestAchievementService.new()

	AchievementTracker.new(_prism_list(), service).attach(from_cloud.simulation)

	assert_eq(service.unlocked, [&"first_sale", &"first_prism"] as Array[StringName])


func test_a_cloud_save_of_an_imported_game_keeps_the_import() -> void:
	# The other device of the player imported the code, and its cloud save
	# carries the record of the import.
	var from_cloud := ExportCode.decode(_content(), ExportCode.encode(_imported_game(), 0))
	assert_true(from_cloud.ok, from_cloud.message)
	var service := TestAchievementService.new()

	AchievementTracker.new(_prism_list(), service).attach(from_cloud.simulation)

	assert_eq(service.unlocked, [] as Array[StringName])


func test_offline_progress_unlocks_its_achievements() -> void:
	var sim := Simulation.new(_content(), SEED)
	var factory: int = _ok(sim.build_factory(&"red"))
	_ok(sim.buy_automatic_transport(_ok(sim.make_link(factory, &"millbrook"))))
	var service := TestAchievementService.new()
	# The simulation does not keep the tracker, so the test keeps it.
	var tracker := AchievementTracker.new(_sample_list(), service)
	tracker.attach(sim)

	sim.progress_offline(ContentFixture.TRANSIT_TIME_MS * 4)

	assert_eq(service.unlocked, [&"first_sale"] as Array[StringName])


func test_an_unavailable_service_gets_the_unlocks_when_it_becomes_available() -> void:
	var service := TestAchievementService.new()
	service.available = false
	var tracker := AchievementTracker.new(_sample_list(), service)
	var sim := Simulation.new(_content(), SEED)
	tracker.attach(sim)
	_sell_once(sim)
	assert_eq(service.unlocked, [] as Array[StringName])

	service.available = true

	assert_eq(service.unlocked, [&"first_sale"] as Array[StringName])


func test_each_achievement_goes_to_the_service_once() -> void:
	var service := _CountingService.new()
	var tracker := AchievementTracker.new(_sample_list(), service)
	var sim := Simulation.new(_content(), SEED)
	tracker.attach(sim)
	_sell_once(sim)

	tracker.sync()
	tracker.attach(sim)

	assert_eq(service.calls, [&"first_sale"] as Array[StringName])


func test_after_attach_the_old_game_unlocks_nothing() -> void:
	var service := TestAchievementService.new()
	var tracker := AchievementTracker.new(_sample_list(), service)
	var old := Simulation.new(_content(), SEED)
	tracker.attach(old)
	tracker.attach(Simulation.new(_content(), SEED))

	_sell_once(old)

	assert_eq(service.unlocked, [] as Array[StringName])


func test_a_list_with_errors_unlocks_nothing() -> void:
	var service := TestAchievementService.new()
	var tracker := AchievementTracker.new(_list([_entry("a", "dance")]), service)
	var sim := Simulation.new(_content(), SEED)
	tracker.attach(sim)

	_sell_once(sim)

	assert_eq(service.unlocked, [] as Array[StringName])


func test_poll_reaches_the_service() -> void:
	var service := _CountingService.new()
	var tracker := AchievementTracker.new(_sample_list(), service)

	tracker.poll()
	tracker.poll()

	assert_eq(service.polls, 2)


## A service that counts each call.
class _CountingService:
	extends AchievementService

	var calls: Array[StringName] = []
	var polls := 0

	func is_available() -> bool:
		return true

	func unlock(def: AchievementDef) -> bool:
		calls.append(def.id)
		return true

	func poll() -> void:
		polls += 1
