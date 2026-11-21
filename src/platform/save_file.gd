class_name SaveFile
extends RefCounted
## Keeps the save text in one file on the device. It knows nothing about the
## text: [SaveCodec] makes and reads it.
##
## A write goes to a temporary file first and then replaces the save, so a game
## that stops during a write keeps the last good save.

const DEFAULT_PATH := "user://save.json"
const _TEMP_SUFFIX := ".tmp"
const _DAMAGED_SUFFIX := ".damaged"

var path: String:
	get:
		return _path

var _path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	_path = p_path


func exists() -> bool:
	return FileAccess.file_exists(_path)


## The save text, or an empty text when the file cannot be read.
func read() -> String:
	return FileAccess.get_file_as_string(_path)


## Replaces the save with [param text].
func write(text: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if error != OK:
		return error
	var temp_path := _path + _TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	error = file.get_error()
	if error != OK:
		return error
	return DirAccess.rename_absolute(temp_path, _path)


## Moves a save that cannot load out of the way, so that the next write does
## not destroy it. Returns the path of the kept copy, or an empty text on failure.
func keep_damaged() -> String:
	var kept_path := _path + _DAMAGED_SUFFIX
	if DirAccess.rename_absolute(_path, kept_path) != OK:
		return ""
	return kept_path
