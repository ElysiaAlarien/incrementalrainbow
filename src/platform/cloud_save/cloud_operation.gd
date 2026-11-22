class_name CloudOperation
extends RefCounted
## One read or write of a [CloudSave]. A platform service can answer later, so
## the operation finishes when the answer comes. Wait for it with
## [method wait], which also works when the answer came at once:
## [codeblock]
## var read := await cloud.read().wait(CloudOperation.TIMEOUT_S)
## [/codeblock]
## The first answer counts. A later answer, for example after a timeout, does
## nothing.

## The operation has its answer.
signal finished

enum Status {
	## No answer yet.
	PENDING,
	## The service did the operation.
	OK,
	## There is no service on this device, or the player is not signed in to
	## it. This is not an error: the game saves only on the device.
	NOT_AVAILABLE,
	## The service is there, but the operation did not work, for example with
	## no network.
	FAILED,
}

## The seconds that the game waits for a service before it stops waiting.
const TIMEOUT_S := 20.0

var status: Status = Status.PENDING
## For a read that is [constant Status.OK]: the text of the cloud save, or an
## empty text when the cloud has no save.
var text := ""
## Why the operation did not work. Text for the player or a log.
var message := ""


## An operation that finished with [param p_text].
static func done(p_text: String = "") -> CloudOperation:
	var operation := CloudOperation.new()
	operation.succeed(p_text)
	return operation


## An operation that finished as [constant Status.NOT_AVAILABLE].
static func not_available(p_message: String) -> CloudOperation:
	var operation := CloudOperation.new()
	operation.fail(Status.NOT_AVAILABLE, p_message)
	return operation


## An operation that finished as [constant Status.FAILED].
static func failed(p_message: String) -> CloudOperation:
	var operation := CloudOperation.new()
	operation.fail(Status.FAILED, p_message)
	return operation


func is_done() -> bool:
	return status != Status.PENDING


func is_ok() -> bool:
	return status == Status.OK


## Gives the answer [constant Status.OK] with [param p_text].
func succeed(p_text: String = "") -> void:
	if is_done():
		return
	status = Status.OK
	text = p_text
	finished.emit()


## Gives the answer [param p_status], which is not [constant Status.OK].
func fail(p_status: Status, p_message: String) -> void:
	assert(p_status != Status.OK and p_status != Status.PENDING, "Use succeed() for a good answer.")
	if is_done():
		return
	status = p_status
	message = p_message
	finished.emit()


## Waits for the answer and returns this operation. With a
## [param timeout_s] above 0, the operation fails when no answer comes in that
## time.
func wait(timeout_s: float = 0.0) -> CloudOperation:
	if not is_done() and timeout_s > 0.0:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.create_timer(timeout_s).timeout.connect(func() -> void:
				fail(Status.FAILED, "The service did not answer in %d seconds." % roundi(timeout_s)))
	if not is_done():
		await finished
	return self
