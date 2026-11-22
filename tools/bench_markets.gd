extends SceneTree
## Measures how long the market queries take: [method Simulation.markets] and
## [method Simulation.forecast] at the forecast horizon, as the main screen
## asks for them.
##
## Usage: godot --headless -s res://tools/bench_markets.gd [-- --generated=100 --runs=600]
##
## It uses the game's own content (39 colors). It times a new game, which has
## the 12 hand-made markets and 3 generated markets (15 in all), and with
## [code]--generated[/code] generated markets. Each game has links that sold
## widgets, so that saturation is in the demand, and the time of at least one
## demand event start. Each run asks for the forecast and then the markets, as
## the main screen does, and then ticks 250 ms, as often as the main screen
## shows the market section. 600 runs cross drift knots, where a query needs
## new knot values. For each query, it prints the time of the first run, which
## fills the caches, and the median, the 95th percentile, and the slowest of
## the other runs. The editor binary runs GDScript with debug checks, so an
## exported game is faster.

const DEFAULT_GENERATED := 100
const DEFAULT_RUNS := 600
## The game time between runs: the time between two refreshes of the market
## section on the main screen.
const STEP_MS := 250


func _init() -> void:
	var generated := DEFAULT_GENERATED
	var runs := DEFAULT_RUNS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--generated="):
			generated = arg.trim_prefix("--generated=").to_int()
		elif arg.begins_with("--runs="):
			runs = arg.trim_prefix("--runs=").to_int()
	var content := Content.load_dir(Content.DEFAULT_DIR)
	assert(content.errors.is_empty(), "; ".join(content.errors))
	var sim := _busy_game(content)
	# 12 hand-made markets and 3 generated markets: 15, as in issue #55.
	_measure(_with_generated_markets(sim, content, 3), runs)
	_measure(_with_generated_markets(sim, content, generated), runs)
	quit()


func _measure(sim: Simulation, runs: int) -> void:
	var colors := sim.markets()[0].prices.size()
	var forecast_us := PackedInt64Array()
	var markets_us := PackedInt64Array()
	var horizon_ms := sim.forecast_horizon_ms()
	for i in runs:
		var begin_us := Time.get_ticks_usec()
		sim.forecast(horizon_ms)
		var middle_us := Time.get_ticks_usec()
		sim.markets()
		markets_us.append(Time.get_ticks_usec() - middle_us)
		forecast_us.append(middle_us - begin_us)
		sim.tick(STEP_MS)
	print("Markets: %d. Colors in each: %d. Runs: %d." % [sim.market_count(), colors, runs])
	# The first queries after a load fill the caches, so they are apart.
	print("  first run: forecast() %.3f ms, markets() %.3f ms" % [forecast_us[0] / 1000.0, markets_us[0] / 1000.0])
	forecast_us.remove_at(0)
	markets_us.remove_at(0)
	print("  forecast(): %s" % _times_text(forecast_us))
	print("  markets(): %s" % _times_text(markets_us))


## The median, the 95th percentile, and the most of [param times_us], in ms.
## The median is the usual cost. Other programs on the computer can make some
## runs slow.
static func _times_text(times_us: PackedInt64Array) -> String:
	var sorted := times_us.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	return "median %.3f ms, 95th percentile %.3f ms, most %.3f ms" % [
		sorted[sorted.size() / 2] / 1000.0, sorted[mini(sorted.size() - 1, sorted.size() * 95 / 100)] / 1000.0,
		sorted[sorted.size() - 1] / 1000.0]


## A game with links to each open market that sold widgets, widgets on their way,
## and the time of at least one demand event start.
func _busy_game(content: Content) -> Simulation:
	var data := {}
	for section in Content.FILES:
		data[section] = JSON.parse_string(FileAccess.get_file_as_string(
			Content.DEFAULT_DIR.path_join(Content.FILES[section])))
	data.balance.run.starting_money = 1e12
	var rich := Content.from_data(data)
	var sim := Simulation.new(rich, 1)
	var open := sim.markets().filter(func(view: MarketView) -> bool: return view.is_open)
	for market: MarketView in open:
		for color: StringName in [&"red", &"yellow", &"blue"]:
			var built := sim.build_factory(color)
			assert(built.ok, built.message)
			var factory: int = built.value
			var made := sim.make_link(factory, market.id)
			assert(made.ok, made.message)
			var bought := sim.buy_automatic_transport(made.value)
			assert(bought.ok, bought.message)
	# Long enough for sales and for the first demand event.
	sim.tick(content.demand_balance.event_interval_max_ms + 1)
	return sim


## A save of [param sim] loaded with [param generated] generated markets.
func _with_generated_markets(sim: Simulation, content: Content, generated: int) -> Simulation:
	var save: Dictionary = JSON.parse_string(SaveCodec.encode(sim, 0))
	save.state.generated_markets = generated
	var result := SaveCodec.decode(content, JSON.stringify(save, "", true, true))
	assert(result.ok, result.message)
	return result.simulation
