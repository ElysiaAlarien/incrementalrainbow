class_name CloudSyncRecord
extends RefCounted
## What this device knows about its last sync with the cloud, in a small file
## beside the save. It is not in the save, because it is true only for this
## device: the save moves between devices, and this record does not.
##
## [code]{"base_sha256": "...", "new_game": false}[/code]

## Added to the save path for the record.
const SUFFIX := ".cloud"

## The SHA-256 of the cloud save after the last good sync, or an empty text.
var base_sha256 := ""
## True when the game on the device started new here and has not synced yet.
var new_game := false

var _file: SaveFile


func _init(save_path: String) -> void:
	_file = SaveFile.new(save_path + SUFFIX)
	if not _file.exists():
		return
	# A damaged record acts as no record. JSON.parse_string logs an error.
	var json := JSON.new()
	if json.parse(_file.read()) != OK:
		return
	var data: Variant = json.data
	if data is Dictionary:
		if data.get("base_sha256") is String:
			base_sha256 = data.base_sha256
		if data.get("new_game") is bool:
			new_game = data.new_game


## The path of the record file.
func path() -> String:
	return _file.path


## Writes the record. A record that cannot be written gives a conflict at the
## next sync, which keeps both saves, so it is not an error for the player.
func write() -> Error:
	return _file.write(JSON.stringify({"base_sha256": base_sha256, "new_game": new_game}))
