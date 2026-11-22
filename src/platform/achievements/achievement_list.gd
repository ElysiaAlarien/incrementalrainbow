class_name AchievementList
extends RefCounted
## The achievements from data/achievements.json, checked against the
## milestones of the content (see [Milestones]). Read-only after load.
##
## Like [Content], it reports each problem as text instead of failing hard. A
## list with errors has no achievements.

const DEFAULT_PATH := "res://data/achievements.json"
const FILE := "achievements.json"

var errors: PackedStringArray:
	get:
		return _errors.duplicate()

var _errors: PackedStringArray = []
var _all: Array[AchievementDef] = []
var _by_milestone: Dictionary[StringName, Array] = {}


## Reads the file at [param path] for [param content].
static func load_file(path: String, content: Content) -> AchievementList:
	var json := JSON.new()
	var list := AchievementList.new()
	if not FileAccess.file_exists(path):
		list._errors.append("cannot read %s: file not found" % path)
	elif json.parse(FileAccess.get_file_as_string(path)) != OK:
		list._errors.append("cannot read %s: %s at line %d" % [path, json.get_error_message(),
			json.get_error_line()])
	elif not json.data is Dictionary:
		list._errors.append("cannot read %s: the top level must be an object" % path)
	else:
		return from_data(json.data, content)
	return list


## Builds the list from parsed data, for [param content].
static func from_data(data: Dictionary, content: Content) -> AchievementList:
	var list := AchievementList.new()
	list._parse(data, Milestones.ids(content))
	if not list._errors.is_empty():
		list._all.clear()
		list._by_milestone.clear()
	return list


## All achievements, in data order.
func all() -> Array[AchievementDef]:
	return _all.duplicate()


## The achievements that [param milestone] grants.
func for_milestone(milestone: StringName) -> Array[AchievementDef]:
	var defs: Array[AchievementDef] = []
	defs.assign(_by_milestone.get(milestone, []))
	return defs


func _parse(data: Dictionary, milestones: Dictionary[StringName, bool]) -> void:
	var entries: Variant = data.get("achievements")
	if not entries is Array:
		_errors.append("%s: \"achievements\" must be a list" % FILE)
		return
	var ids := {}
	var platform_ids := {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			_errors.append("%s: each achievement must be an object" % FILE)
			continue
		var id := _text(entry, "id")
		if id.is_empty():
			_errors.append("%s: an achievement has no id" % FILE)
			continue
		if ids.has(id):
			_errors.append("%s: duplicate achievement id %s" % [FILE, id])
			continue
		ids[id] = true
		var name := _text(entry, "name")
		var description := _text(entry, "description")
		if name.is_empty():
			_errors.append("%s: %s has no name" % [FILE, id])
		if description.is_empty():
			_errors.append("%s: %s has no description" % [FILE, id])
		var milestone := StringName(_text(entry, "milestone"))
		if not milestones.has(milestone):
			_errors.append("%s: %s has the milestone \"%s\", which the game does not have" % [FILE, id,
				milestone])
		var at_least := _read_at_least(entry, id, milestone)
		var by_platform := _read_platform_ids(entry, id, platform_ids)
		var def := AchievementDef.new(StringName(id), name, description, milestone, at_least, by_platform)
		_all.append(def)
		if not _by_milestone.has(milestone):
			_by_milestone[milestone] = []
		_by_milestone[milestone].append(def)


func _read_at_least(entry: Dictionary, id: String, milestone: StringName) -> int:
	var value: Variant = entry.get("at_least", 1)
	if not (value is int or value is float) or value < 1 or value != floorf(value) or value >= 9.0e15:
		_errors.append("%s: %s.at_least must be a positive integer" % [FILE, id])
		return 1
	if value > 1 and not Milestones.COUNTS.has(milestone):
		_errors.append("%s: %s.at_least must be 1, because \"%s\" is not a count" % [FILE, id, milestone])
	return int(value)


## Reads "platform_ids" of [param entry]. [param seen] has each id of each
## platform so far, so that two achievements cannot have the same id.
func _read_platform_ids(entry: Dictionary, id: String, seen: Dictionary) -> Dictionary[StringName, String]:
	var by_platform: Dictionary[StringName, String] = {}
	var value: Variant = entry.get("platform_ids", {})
	if not value is Dictionary:
		_errors.append("%s: %s.platform_ids must be an object" % [FILE, id])
		return by_platform
	for key: Variant in value:
		var platform := StringName(str(key))
		if not AchievementDef.PLATFORMS.has(platform):
			_errors.append("%s: %s.platform_ids has the platform \"%s\", which the game does not have" % [
				FILE, id, platform])
			continue
		var platform_id: Variant = value[key]
		if not platform_id is String:
			_errors.append("%s: %s.platform_ids.%s must be text" % [FILE, id, platform])
			continue
		if platform_id.is_empty():
			continue
		var seen_key := "%s/%s" % [platform, platform_id]
		if seen.has(seen_key):
			_errors.append("%s: %s and %s have the same %s id \"%s\"" % [FILE, seen[seen_key], id,
				platform, platform_id])
			continue
		seen[seen_key] = id
		by_platform[platform] = platform_id
	return by_platform


static func _text(entry: Dictionary, key: String) -> String:
	var value: Variant = entry.get(key, "")
	return value if value is String else ""
