class_name AchievementDef
extends RefCounted
## One achievement from data/achievements.json: the milestone that grants it,
## and its id on each platform. Read-only.

## The platforms that can have an id for an achievement, as keys of
## "platform_ids" in the data.
const PLATFORMS: Array[StringName] = [&"steam", &"game_center", &"google_play"]

var id: StringName:
	get:
		return _id
var name: String:
	get:
		return _name
var description: String:
	get:
		return _description
## The milestone (see [Milestones]) that grants the achievement.
var milestone: StringName:
	get:
		return _milestone
## The value of [member milestone] that grants the achievement.
var at_least: int:
	get:
		return _at_least

var _id: StringName
var _name: String
var _description: String
var _milestone: StringName
var _at_least: int
var _platform_ids: Dictionary[StringName, String]


func _init(p_id: StringName, p_name: String, p_description: String, p_milestone: StringName,
		p_at_least: int, p_platform_ids: Dictionary[StringName, String]) -> void:
	_id = p_id
	_name = p_name
	_description = p_description
	_milestone = p_milestone
	_at_least = p_at_least
	_platform_ids = p_platform_ids.duplicate()


## The id of the achievement on [param platform], or an empty text when the
## data has none yet.
func platform_id(platform: StringName) -> String:
	return _platform_ids.get(platform, "")


## True when the milestone [param value] grants the achievement on the
## platform. [param imported] is the value that the milestone had when the
## player imported the game from an export code (see
## [method Simulation.imported_milestones]), or 0. An import that already
## had the value [member at_least] does not grant it: only the player's own
## progress after the import does (ADR-0019).
func is_earned(value: int, imported: int) -> bool:
	return value >= _at_least and _at_least > imported
