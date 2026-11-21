class_name PrismBalance
extends RefCounted
## Balance values for prisms, from balance.json. Read-only. All values are
## placeholders until playtests set them. See ADR-0003.

## The price of the first prism of the game.
var first_price: BigNumber:
	get:
		return _first_price
## Each prism costs this many times the one before it.
var price_growth: float:
	get:
		return _price_growth

var _first_price: BigNumber
var _price_growth: float


func _init(p_first_price: BigNumber, p_price_growth: float) -> void:
	_first_price = p_first_price
	_price_growth = p_price_growth


## The price of the next prism when [param total_bought] prisms were bought
## across all runs. Prices are whole numbers. The content check that
## [code]first_price * (price_growth - 1)[/code] is at least 1 makes each price
## higher than the one before it.
func price(total_bought: int) -> BigNumber:
	return _first_price.times_power(_price_growth, total_bought).ceiled()
