class_name ColorDef
extends RefCounted
## One color from the content data. Read-only.

## What makes the color available in a run.
enum Unlock {
	## Available from the start of each run.
	START,
	## Research in a run unlocks it.
	RESEARCH,
	## A prestige upgrade unlocks it, for this run and all later runs.
	PRESTIGE_UPGRADE,
}

## The [enum Unlock] value for each name in colors.json.
const UNLOCK_NAMES: Dictionary[String, Unlock] = {
	"start": Unlock.START,
	"research": Unlock.RESEARCH,
	"prestige_upgrade": Unlock.PRESTIGE_UPGRADE,
}

## A mark drawn on the symbol. A tint and a shade have the symbol of their hue
## with a mark, so that a colorblind player can see the hue and whether it is
## a tint or a shade.
enum SymbolMark {
	## No mark.
	NONE,
	## The mark of a tint.
	TINT,
	## The mark of a shade.
	SHADE,
}

## The [enum SymbolMark] value for each name in colors.json.
const SYMBOL_MARK_NAMES: Dictionary[String, SymbolMark] = {
	"none": SymbolMark.NONE,
	"tint": SymbolMark.TINT,
	"shade": SymbolMark.SHADE,
}

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
## The mark drawn on [member symbol]. The symbol and the mark together are
## different for each color.
var symbol_mark: SymbolMark:
	get:
		return _symbol_mark
var display_color: Color:
	get:
		return _display_color
## Input color id to the count consumed to make one widget. Empty for a base
## color. Returns a copy.
var recipe: Dictionary[StringName, int]:
	get:
		return _recipe.duplicate()

## What makes the color available in a run. The simulation decides whether it
## is available now.
var unlock: Unlock:
	get:
		return _unlock

var _id: StringName
var _name: String
var _symbol: StringName
var _display_color: Color
var _recipe: Dictionary[StringName, int]
var _unlock: Unlock
var _symbol_mark: SymbolMark


func _init(p_id: StringName, p_name: String, p_symbol: StringName,
		p_display_color: Color, p_recipe: Dictionary[StringName, int],
		p_unlock: Unlock = Unlock.START, p_symbol_mark: SymbolMark = SymbolMark.NONE) -> void:
	_id = p_id
	_name = p_name
	_symbol = p_symbol
	_display_color = p_display_color
	_recipe = p_recipe.duplicate()
	_unlock = p_unlock
	_symbol_mark = p_symbol_mark


func is_base() -> bool:
	return _recipe.is_empty()
