class_name MarketGenerator
extends RefCounted
## The rules that make markets after the hand-made markets, from the
## "generator" object of markets.json, and the generator that applies them.
## Read-only. All values are placeholders until playtests set them.
##
## Generated market [code]n[/code] (1, 2, 3, and so on) is a pure function of a
## key and [code]n[/code], as drift is (ADR-0011). The simulation keeps only the
## key and the count of generated markets, so the same key gives the same
## markets each time, and a market does not depend on when the game made it.
## There is no limit on [code]n[/code].
## [br][br]
## The rules:
## [br]- Remoteness: the most remote hand-made market, plus
##   [member remoteness_step] times [code]n[/code]. So each generated market is
##   more remote than the one before it.
## [br]- Population and income: a base plus an amount for each step of
##   remoteness, times a random factor from 1 - [member spread] to
##   1 + [member spread]. So more remote markets are larger and pay more.
## [br]- Base prices: for each color, the lowest base price of that color in
##   the hand-made markets. [member favored_colors] colors, chosen at random,
##   have [member favored_price_factor] times that price.
## [br]- Name: a start from [member name_starts] and an end from
##   [member name_ends], such as "Stonehaven". All pairs come once, in an order
##   that the key sets, before a pair comes again with a number, such as
##   "Stonehaven 2".
## [br]- Id: [constant ID_PREFIX] and [code]n[/code], such as "generated_1".

## The start of each generated market id. No hand-made market id can start
## with it.
const ID_PREFIX := "generated_"
## Mixed into the key, so that the generator and drift get other random values
## from the same key.
const _SALT := 0x6D61726B
const _MASK32 := 0xFFFFFFFF

## The game makes generated markets until at least this many markets are
## closed to the player's transport tier, so that the player can always see
## the next markets to reach.
var closed_markets_shown: int:
	get:
		return _closed_markets_shown
## Each generated market is this much more remote than the one before it.
var remoteness_step: int:
	get:
		return _remoteness_step
var population_base: int:
	get:
		return _population_base
var population_per_remoteness: int:
	get:
		return _population_per_remoteness
var income_base: int:
	get:
		return _income_base
var income_per_remoteness: int:
	get:
		return _income_per_remoteness
## The most that the random factor moves population and income, from 0 up to
## but not including 1. 0.2 gives 0.8 to 1.2 times the value.
var spread: float:
	get:
		return _spread
## How many colors of each generated market have a higher base price.
var favored_colors: int:
	get:
		return _favored_colors
var favored_price_factor: float:
	get:
		return _favored_price_factor
var name_starts: PackedStringArray:
	get:
		return _name_starts
var name_ends: PackedStringArray:
	get:
		return _name_ends

var _closed_markets_shown: int
var _remoteness_step: int
var _population_base: int
var _population_per_remoteness: int
var _income_base: int
var _income_per_remoteness: int
var _spread: float
var _favored_colors: int
var _favored_price_factor: float
var _name_starts: PackedStringArray
var _name_ends: PackedStringArray
## The remoteness of the most remote hand-made market.
var _first_remoteness: int
## Color id to the base price before favored colors, in content color order.
var _base_prices: Dictionary[StringName, BigNumber]
## A step through the name pairs that has no factor in common with their
## count, so that one pass gives each pair once.
var _name_stride: int


func _init(rules: Dictionary, hand_made: Array[MarketDef], colors: Array[ColorDef]) -> void:
	_closed_markets_shown = rules.closed_markets_shown
	_remoteness_step = rules.remoteness_step
	_population_base = rules.population_base
	_population_per_remoteness = rules.population_per_remoteness
	_income_base = rules.income_base
	_income_per_remoteness = rules.income_per_remoteness
	_spread = rules.spread
	_favored_colors = mini(rules.favored_colors, colors.size())
	_favored_price_factor = rules.favored_price_factor
	_name_starts = rules.name_starts
	_name_ends = rules.name_ends
	_first_remoteness = 0
	for def in hand_made:
		_first_remoteness = maxi(_first_remoteness, def.remoteness)
	for color in colors:
		var lowest: BigNumber = null
		for def in hand_made:
			var price := def.price(color.id)
			if price != null and (lowest == null or price.is_less_than(lowest)):
				lowest = price
		_base_prices[color.id] = lowest if lowest != null else BigNumber.from_int(1)
	var pairs := maxi(1, _name_starts.size() * _name_ends.size())
	_name_stride = maxi(1, int(pairs * 0.618))
	while _gcd(_name_stride, pairs) != 1:
		_name_stride += 1


## The remoteness of generated market [param index] (1 or more).
func remoteness(index: int) -> int:
	return _first_remoteness + _remoteness_step * index


## Generated market [param index] (1 or more) for [param key], a 32-bit
## value from the run's random number generator.
func generate(key: int, index: int) -> MarketDef:
	assert(index >= 1, "generated markets start at 1")
	var rng := SimRng.new((index << 32) | ((key ^ _SALT) & _MASK32))
	var distance := remoteness(index)
	var population := _vary(_population_base + _population_per_remoteness * distance, rng)
	var income := _vary(_income_base + _income_per_remoteness * distance, rng)
	var prices := _base_prices.duplicate()
	var colors: Array[StringName] = []
	for color: StringName in _base_prices:
		colors.append(color)
	for i in _favored_colors:
		var color: StringName = colors.pop_at(rng.randi_range(0, colors.size() - 1))
		prices[color] = prices[color].mul(BigNumber.from_float(_favored_price_factor))
	return MarketDef.new(StringName(ID_PREFIX + str(index)), _name(key, index), prices,
		population, income, distance)


## The capacity check for [method Content]: the smallest population that a
## generated market can have.
func smallest_population() -> int:
	return _vary_low(_population_base + _population_per_remoteness * remoteness(1))


func _name(key: int, index: int) -> String:
	var pairs := _name_starts.size() * _name_ends.size()
	if pairs == 0:
		return "Market %d" % index
	var offset := SimRng.new((key ^ _SALT) & _MASK32).randi_range(0, pairs - 1)
	@warning_ignore("integer_division")
	var pass_number := (index - 1) / pairs
	var pair := (offset + ((index - 1) % pairs) * _name_stride) % pairs
	@warning_ignore("integer_division")
	var start := _name_starts[pair / _name_ends.size()]
	var text := start + _name_ends[pair % _name_ends.size()]
	return text if pass_number == 0 else "%s %d" % [text, pass_number + 1]


func _vary(value: int, rng: SimRng) -> int:
	var factor := 1.0 + _spread * (2.0 * rng.randf() - 1.0)
	return maxi(1, roundi(value * factor))


func _vary_low(value: int) -> int:
	return maxi(1, floori(value * (1.0 - _spread)))


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := a % b
		a = b
		b = t
	return a
