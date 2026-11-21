class_name ResearchDef
extends RefCounted
## One research from the content data: its widget cost, the research it
## requires, and what it unlocks. Read-only.

## The kinds of unlock that research.json can give, as keys of "unlocks".
## Each key that a later ticket adds goes here and gets its own field.
const UNLOCK_KINDS: PackedStringArray = ["colors"]

var id: StringName:
	get:
		return _id
var name: String:
	get:
		return _name
## Color id to the count of widgets of that color that a lab consumes to
## complete this research. Returns a copy.
var cost: Dictionary[StringName, int]:
	get:
		return _cost.duplicate()
## The research that must be complete before the player can select this one.
## Each comes before this one in the data. Returns a copy.
var requires: Array[StringName]:
	get:
		return _requires.duplicate()
## The colors, and with them their recipes, that this research unlocks.
## Returns a copy.
var unlock_colors: Array[StringName]:
	get:
		return _unlock_colors.duplicate()

var _id: StringName
var _name: String
var _cost: Dictionary[StringName, int]
var _requires: Array[StringName]
var _unlock_colors: Array[StringName]


func _init(p_id: StringName, p_name: String, p_cost: Dictionary[StringName, int],
		p_requires: Array[StringName], p_unlock_colors: Array[StringName]) -> void:
	_id = p_id
	_name = p_name
	_cost = p_cost.duplicate()
	_requires = p_requires.duplicate()
	_unlock_colors = p_unlock_colors.duplicate()


## True if this research unlocks [param color].
func unlocks_color(color: StringName) -> bool:
	return _unlock_colors.has(color)
