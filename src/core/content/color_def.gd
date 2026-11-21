class_name ColorDef
extends RefCounted
## One color from the content data. Read-only after load.

var id: StringName
var name: String
## The shape shown next to the color, so that colorblind players can tell
## colors apart. The UI decides how to draw each symbol.
var symbol: StringName
var display_color: Color
## Input color id to the count consumed to make one widget. Empty for a base color.
var recipe: Dictionary[StringName, int]


func is_base() -> bool:
	return recipe.is_empty()
