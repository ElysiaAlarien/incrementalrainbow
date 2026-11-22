class_name CloudSaveSession
extends RefCounted
## Syncs the game on the device with one [CloudSave]: it reads the cloud,
## decides with [method CloudSync.decide], writes the cloud, and keeps the
## [CloudSyncRecord]. It never changes the game itself: it emits
## [signal synced] with the plan, and the screen applies it.
##
## Only one sync runs at a time. A sync never waits longer than
## [member timeout_s] for each answer, and the game plays while it waits.

## A sync finished with [param plan]. For [constant CloudSyncPlan.Action.USE_CLOUD],
## the screen replaces its game with [member CloudSyncPlan.cloud].
signal synced(plan: CloudSyncPlan)

## Added to the save path for the copy of the save that a sync did not use.
const KEPT_SUFFIX := ".other"

## The seconds to wait for each answer of the service.
var timeout_s := CloudOperation.TIMEOUT_S

var _cloud: CloudSave
var _content: Content
var _record: CloudSyncRecord
var _kept_file: SaveFile
var _busy := false
var _stopped := false


func _init(cloud: CloudSave, content: Content, save_path: String) -> void:
	_cloud = cloud
	_content = content
	_record = CloudSyncRecord.new(save_path)
	_kept_file = SaveFile.new(save_path + KEPT_SUFFIX)


## The name of the service for the player.
func service_name() -> String:
	return _cloud.service_name()


## True while a sync waits for the service.
func is_busy() -> bool:
	return _busy


## True after a sync found a cloud save of a newer game. No sync runs again
## until the game starts again.
func is_stopped() -> bool:
	return _stopped


## Records that the game on the device started new here, so that a cloud
## save replaces it at the next sync.
func mark_new_game() -> void:
	_record.new_game = true
	_write_record()


## The export code of the save that the last sync did not use, or an empty
## text.
func kept_code() -> String:
	return _kept_file.read() if _kept_file.exists() else ""


## Keeps [param code] in place of the kept save, for example when the player
## changes to the kept save.
func keep(code: String) -> void:
	var error := _kept_file.write(code)
	if error != OK:
		push_warning("Could not keep the other save at %s: %s" % [_kept_file.path, error_string(error)])


## Syncs the game on the device, whose export code is [param local_code] and
## whose save time is [param local_saved_at_unix_ms]. With
## [param can_tell_player] false (when the game goes to the background or
## quits), a sync only uploads: a plan that changes the game or tells the
## player waits for the next sync. Returns the plan, or null when no sync ran.
func sync(local_code: String, local_saved_at_unix_ms: int, can_tell_player: bool) -> CloudSyncPlan:
	if _busy or _stopped:
		return null
	_busy = true
	var read := await _cloud.read().wait(timeout_s)
	var plan := CloudSync.decide(_content, local_code, local_saved_at_unix_ms, _record.new_game,
		read, _record.base_sha256)
	if not can_tell_player and plan.needs_the_player():
		plan = CloudSyncPlan.make(CloudSyncPlan.Action.NOTHING)
	match plan.action:
		CloudSyncPlan.Action.UPLOAD:
			var written := await _cloud.write(local_code).wait(timeout_s)
			if written.is_ok():
				_record_sync(plan.synced_sha256)
			elif written.status == CloudOperation.Status.FAILED and can_tell_player:
				if plan.notice == CloudSyncPlan.Notice.NONE:
					plan.notice = CloudSyncPlan.Notice.UNREACHABLE
				plan.message = written.message
		CloudSyncPlan.Action.USE_CLOUD:
			_record_sync(plan.synced_sha256)
		CloudSyncPlan.Action.NOTHING:
			if not plan.synced_sha256.is_empty():
				_record_sync(plan.synced_sha256)
		CloudSyncPlan.Action.STOP:
			_stopped = true
	if not plan.kept_code.is_empty():
		keep(plan.kept_code)
	_busy = false
	synced.emit(plan)
	return plan


func _record_sync(sha256: String) -> void:
	if _record.base_sha256 == sha256 and not _record.new_game:
		return
	_record.base_sha256 = sha256
	_record.new_game = false
	_write_record()


func _write_record() -> void:
	var error := _record.write()
	if error != OK:
		push_warning("Could not write the cloud sync record at %s: %s" % [_record.path(), error_string(error)])
