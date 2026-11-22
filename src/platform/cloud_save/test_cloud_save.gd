class_name TestCloudSave
extends CloudSave
## A cloud save with no platform service, for tests and for a person who tests
## the game on one computer.
##
## It keeps the save in memory, or in a folder when [member folder] is set. Two
## copies of the game with their own save path and the same folder act as two
## devices with one cloud. To start the game with it, give the folder after
## [code]--[/code] on the command line:
## [codeblock]
## godot --path . -- --test-cloud-save=/tmp/ir-cloud --save-path=user://device_b.json
## [/codeblock]
## Tests can make it unavailable, make the next operation fail, and hold the
## answers to test a service that answers later.

## The file in [member folder] that holds the save.
const FILE_NAME := "cloud_save.txt"

## False acts as a device that has the service but where the player is not
## signed in.
var available := true
## The folder that keeps the save, or an empty text to keep it in memory.
var folder := ""
## When not empty, the next read fails with this message.
var fail_next_read := ""
## When not empty, the next write fails with this message.
var fail_next_write := ""
## True holds each answer until [method answer_held] or [method lose_held].
var hold_answers := false
## The count of reads and writes that the game asked for.
var reads := 0
var writes := 0

var _text := ""
var _held: Array[Callable] = []


func _init(p_folder: String = "") -> void:
	folder = p_folder


func service_name() -> String:
	return "test cloud save"


func is_available() -> bool:
	return available


## The save in the cloud, or an empty text. For tests.
func stored_text() -> String:
	if folder.is_empty():
		return _text
	return FileAccess.get_file_as_string(folder.path_join(FILE_NAME))


## Puts [param text] in the cloud, as another device does. For tests.
func put(text: String) -> void:
	if folder.is_empty():
		_text = text
	else:
		var error := SaveFile.new(folder.path_join(FILE_NAME)).write(text)
		assert(error == OK, "Could not write the test cloud save: %s" % error_string(error))


func read() -> CloudOperation:
	reads += 1
	if not available:
		return CloudOperation.not_available("Not signed in to the %s." % service_name())
	var operation := CloudOperation.new()
	var problem := fail_next_read
	fail_next_read = ""
	_answer(func() -> void:
		if problem.is_empty():
			operation.succeed(stored_text())
		else:
			operation.fail(CloudOperation.Status.FAILED, problem))
	return operation


func write(text: String) -> CloudOperation:
	writes += 1
	if not available:
		return CloudOperation.not_available("Not signed in to the %s." % service_name())
	var operation := CloudOperation.new()
	var problem := fail_next_write
	fail_next_write = ""
	_answer(func() -> void:
		if problem.is_empty():
			put(text)
			operation.succeed()
		else:
			operation.fail(CloudOperation.Status.FAILED, problem))
	return operation


## The count of operations that wait for their answer.
func held_count() -> int:
	return _held.size()


## Gives the answers that [member hold_answers] held, in order.
func answer_held() -> void:
	var held := _held
	_held = []
	for answer in held:
		answer.call()


## Drops the held answers, as a service that never answers.
func lose_held() -> void:
	_held = []


func _answer(answer: Callable) -> void:
	if hold_answers:
		_held.append(answer)
	else:
		answer.call()
