class_name CloudSync
extends RefCounted
## The rule for one sync between the save on the device and the cloud save
## (ADR-0018). It reads and writes nothing, so tests can give it each case.
##
## A sync compares three saves, each an export code: the game on the device,
## the cloud save, and the cloud save after the last good sync on this device
## (by its SHA-256, the sync base). Thus the game knows which side changed:
## - Only the device changed: upload it.
## - Only the cloud changed (another device played): use the cloud save.
## - Both changed, or there is no sync base: a conflict. The save with the
##   later save time wins. On a tie, the device wins. The other save is kept.
## A game that started new on this device and never synced loses to a cloud
## save, so that a new install cannot replace a long game. The player is told,
## and the new game is kept, because it can be a long game on a device that had
## no cloud for a long time.


## The plan for a sync. [param local_code] is the export code of the game on
## the device, and [param local_saved_at_unix_ms] its save time.
## [param local_is_new] is true when that game started on this device and has
## not synced yet. [param read] is the finished read of the cloud save, and
## [param base_sha256] the sync base, or an empty text.
static func decide(content: Content, local_code: String, local_saved_at_unix_ms: int,
		local_is_new: bool, read: CloudOperation, base_sha256: String) -> CloudSyncPlan:
	assert(read.is_done(), "Wait for the read first.")
	if read.status == CloudOperation.Status.NOT_AVAILABLE:
		return CloudSyncPlan.make(CloudSyncPlan.Action.NOTHING)
	if not read.is_ok():
		var unreachable := CloudSyncPlan.make(CloudSyncPlan.Action.NOTHING, CloudSyncPlan.Notice.UNREACHABLE)
		unreachable.message = read.message
		return unreachable

	var local_sha := local_code.sha256_text()
	if read.text.is_empty():
		return _upload(local_sha)
	var cloud_sha := read.text.sha256_text()
	if cloud_sha == local_sha:
		var same := CloudSyncPlan.make(CloudSyncPlan.Action.NOTHING)
		same.synced_sha256 = cloud_sha
		return same

	var cloud := ExportCode.decode(content, read.text)
	if not cloud.ok:
		if cloud.reason == LoadResult.Reason.NEWER_VERSION:
			var newer := CloudSyncPlan.make(CloudSyncPlan.Action.STOP, CloudSyncPlan.Notice.CLOUD_NEWER)
			newer.message = cloud.message
			return newer
		var damaged := _upload(local_sha, CloudSyncPlan.Notice.CLOUD_DAMAGED)
		damaged.kept_code = read.text
		damaged.message = cloud.message
		return damaged

	# Before the sync base: a device that synced before can start a new game
	# (its save did not load), and that game must not replace the cloud save.
	if local_is_new:
		var replaced := _use_cloud(cloud, cloud_sha, CloudSyncPlan.Notice.REPLACED_NEW_GAME)
		_keep(replaced, local_code, local_saved_at_unix_ms)
		return replaced
	if cloud_sha == base_sha256:
		return _upload(local_sha)
	if local_sha == base_sha256:
		var loaded := _use_cloud(cloud, cloud_sha, CloudSyncPlan.Notice.LOADED_FROM_CLOUD)
		_keep(loaded, local_code, local_saved_at_unix_ms)
		return loaded

	if cloud.saved_at_unix_ms > local_saved_at_unix_ms:
		var cloud_wins := _use_cloud(cloud, cloud_sha, CloudSyncPlan.Notice.CONFLICT)
		cloud_wins.picked_cloud = true
		_keep(cloud_wins, local_code, local_saved_at_unix_ms)
		return cloud_wins
	var local_wins := _upload(local_sha, CloudSyncPlan.Notice.CONFLICT)
	local_wins.used_saved_at_unix_ms = local_saved_at_unix_ms
	local_wins.kept_code = read.text
	local_wins.kept_saved_at_unix_ms = cloud.saved_at_unix_ms
	return local_wins


static func _upload(local_sha: String,
		notice: CloudSyncPlan.Notice = CloudSyncPlan.Notice.NONE) -> CloudSyncPlan:
	var plan := CloudSyncPlan.make(CloudSyncPlan.Action.UPLOAD, notice)
	plan.synced_sha256 = local_sha
	return plan


static func _use_cloud(cloud: LoadResult, cloud_sha: String,
		notice: CloudSyncPlan.Notice) -> CloudSyncPlan:
	var plan := CloudSyncPlan.make(CloudSyncPlan.Action.USE_CLOUD, notice)
	plan.cloud = cloud
	plan.used_saved_at_unix_ms = cloud.saved_at_unix_ms
	plan.synced_sha256 = cloud_sha
	return plan


static func _keep(plan: CloudSyncPlan, code: String, saved_at_unix_ms: int) -> void:
	plan.kept_code = code
	plan.kept_saved_at_unix_ms = saved_at_unix_ms
