class_name DemandEventDef
extends RefCounted
## One demand event from the content data: a short, named spike or crash in
## the demand for one or more colors. Read-only.
##
## While the event is active, the demand of each of its colors in each market
## is multiplied by [method factor].

enum Direction { SPIKE, CRASH }

## The text in the data for each direction.
const DIRECTION_NAMES: Dictionary[String, Direction] = {
	"spike": Direction.SPIKE,
	"crash": Direction.CRASH,
}

var id: StringName:
	get:
		return _id
var name: String:
	get:
		return _name
## The colors whose demand changes, in data order. Returns a copy.
var colors: Array[StringName]:
	get:
		return _colors.duplicate()
var direction: Direction:
	get:
		return _direction
## How much demand changes, as a fraction of demand. A spike of 0.5 makes
## demand 1.5 times as high. A crash of 0.4 makes it 0.6 times as high, and a
## crash is less than 1, so that demand stays above 0.
var size: float:
	get:
		return _size
## How long the event lasts.
var duration_ms: int:
	get:
		return _duration_ms

var _id: StringName
var _name: String
var _colors: Array[StringName]
var _direction: Direction
var _size: float
var _duration_ms: int


func _init(p_id: StringName, p_name: String, p_colors: Array[StringName], p_direction: Direction,
		p_size: float, p_duration_ms: int) -> void:
	_id = p_id
	_name = p_name
	_colors = p_colors.duplicate()
	_direction = p_direction
	_size = p_size
	_duration_ms = p_duration_ms


## True if the event changes the demand of [param color].
func has_color(color: StringName) -> bool:
	return _colors.has(color)


## The number that the event multiplies the demand of its colors by: more
## than 1 for a spike, and from 0 to 1 for a crash.
func factor() -> float:
	return 1.0 + _size if _direction == Direction.SPIKE else 1.0 - _size
