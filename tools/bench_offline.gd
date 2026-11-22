extends SceneTree
## Measures how long offline progress takes for a long time away.
##
## Usage: godot --headless -s res://tools/bench_offline.gd [-- --hours=24 --groups=3]
##
## It builds a busy game with the game's own content (with more starting
## money): groups of base and mixed factories with automatic links to the
## market and to the mixed factories, bought at different times so that their
## events do not line up. Each group has 6 factories and 12 links. Then it
## times offline progress for the time away, and prints the events and the
## time for each event.

const DEFAULT_HOURS := 24.0
const DEFAULT_GROUPS := 3


func _init() -> void:
	var hours := DEFAULT_HOURS
	var groups := DEFAULT_GROUPS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hours="):
			hours = arg.trim_prefix("--hours=").to_float()
		elif arg.begins_with("--groups="):
			groups = arg.trim_prefix("--groups=").to_int()
	var sim := _busy_game(groups)
	var away_ms := int(hours * 3_600_000.0)
	var before := sim.links()
	var started_before := _shipments_started(sim)
	var begin_us := Time.get_ticks_usec()
	var summary := sim.progress_offline(away_ms)
	var elapsed_us := Time.get_ticks_usec() - begin_us
	var started := _shipments_started(sim) - started_before
	# Each automatic link has one start each transit time of its vehicle, with
	# or without a shipment. Each shipment also arrives.
	var automatic_starts := 0
	for view in before:
		@warning_ignore("integer_division")
		automatic_starts += away_ms / view.transit_time_ms
	var events := automatic_starts + started
	print("Links: %d (all automatic). Factories: %d." % [before.size(), sim.factories().size()])
	print("Time away: %.1f h. Automatic starts: %d. Shipments: %d. Widgets made: %d. Widgets sold: %d. Money earned: %s." % [
		hours, automatic_starts, started, summary.widgets_made, summary.widgets_sold, summary.money_earned.format()])
	print("Offline progress took %.2f s (%.2f us for each event: start or arrival)." % [
		elapsed_us / 1e6, float(elapsed_us) / maxi(events, 1)])
	quit()


## Shipment ids are given in order, so the next id counts the shipments.
func _shipments_started(sim: Simulation) -> int:
	return int(sim.snapshot().next_shipment_id) - 1


func _busy_game(groups: int) -> Simulation:
	var data := {}
	for section in Content.FILES:
		data[section] = JSON.parse_string(FileAccess.get_file_as_string(
			Content.DEFAULT_DIR.path_join(Content.FILES[section])))
	data.balance.run.starting_money = 1e12
	var content := Content.from_data(data)
	assert(content.errors.is_empty(), "; ".join(content.errors))
	var sim := Simulation.new(content, 1)
	var market: StringName = content.markets()[0].id
	var links: Array[int] = []
	# Each group of red, yellow, and blue factories feeds one green, one
	# orange, and one purple factory, and sells its other widgets.
	for group in groups:
		var base := {}
		for color: StringName in [&"red", &"yellow", &"blue"]:
			base[color] = _factory(sim, color, 4)
			links.append(sim.make_link(base[color], market).value)
		for mixed: StringName in [&"green", &"orange", &"purple"]:
			var id := _factory(sim, mixed, 2)
			for input in content.color(mixed).recipe:
				links.append(sim.make_factory_link(base[input], id).value)
			links.append(sim.make_link(id, market).value)
	for link_id in links:
		var bought := sim.buy_automatic_transport(link_id)
		assert(bought.ok, bought.message)
		sim.tick(337)
	return sim


func _factory(sim: Simulation, color: StringName, lines: int) -> int:
	var id: int = sim.build_factory(color).value
	for i in lines - 1:
		sim.add_production_line(id)
	return id
