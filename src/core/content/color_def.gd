class_name ColorDef
extends RefCounted
## One color from the content data. Read-only.

var id: StringName:
	get:
		return _id
var name: String:
	get:
		return _name
## The shape shown next to the color, so that colorblind players can tell
## colors apart. The UI decides how to draw each symbol.
var symbol: StringName:
	get:
		return _symbol
var display_color: Color:
	get:
		return _display_color
## Input color id to the count consumed to make one widget. Empty for a base
## color. Returns a copy.
var recipe: Dictionary[StringName, int]:
	get:
		return _recipe.duplicate()

var _id: StringName
var _name: String
var _symbol: StringName
var _display_color: Color
var _recipe: Dictionary[StringName, int]


func _init(p_id: StringName, p_name: String, p_symbol: StringName,
		p_display_color: Color, p_recipe: Dictionary[StringName, int]) -> void:
	_id = p_id
	_name = p_name
	_symbol = p_symbol
	_display_color = p_display_color
	_recipe = p_recipe.duplicate()


func is_base() -> bool:
	return _recipe.is_empty()
