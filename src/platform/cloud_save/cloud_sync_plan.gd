class_name CloudSyncPlan
extends RefCounted
## What one sync with the cloud does, from [method CloudSync.decide], and what
## the game tells the player.

enum Action {
	## Change nothing.
	NOTHING,
	## Keep the game on the device, and write it to the cloud.
	UPLOAD,
	## Replace the game on the device with the cloud save in [member cloud].
	USE_CLOUD,
	## Keep the game on the device, and do not read or write the cloud again
	## until the game starts again. For a cloud save of a newer game, which
	## an upload would destroy.
	STOP,
}

enum Notice {
	## Nothing to tell the player.
	NONE,
	## The cloud could not be read or written. The game saves on the device.
	UNREACHABLE,
	## The cloud had a newer save of this game from another device, and the
	## game on this device had no change since the last sync (or is a new
	## game), so the game uses the cloud save.
	LOADED_FROM_CLOUD,
	## The game on the device and the cloud save both changed since the last
	## sync. The rule of ADR-0018 picked one. [member kept_code] is the other.
	CONFLICT,
	## The cloud save cannot load. The game keeps a copy and uploads the game
	## on the device.
	CLOUD_DAMAGED,
	## A newer version of the game made the cloud save.
	CLOUD_NEWER,
}

var action: Action = Action.NOTHING
var notice: Notice = Notice.NONE
## For [constant Action.USE_CLOUD]: the loaded cloud save.
var cloud: LoadResult
## The save that the plan does not use, as an export code, or an empty text.
## The game keeps a copy of it on the device, so that a sync never destroys a
## save.
var kept_code := ""
## The save time of the save that the game uses, and of the kept save, in Unix
## ms, or [constant LoadResult.NO_SAVE_TIME]. For the text to the player.
var used_saved_at_unix_ms: int = LoadResult.NO_SAVE_TIME
var kept_saved_at_unix_ms: int = LoadResult.NO_SAVE_TIME
## For [constant Notice.CONFLICT]: true when the rule picked the cloud save.
var picked_cloud := false
## The SHA-256 of the cloud save after the plan is done. [CloudSaveSession]
## records it when the plan is done.
var synced_sha256 := ""
## Text for the player or a log, for example why the cloud did not answer.
var message := ""


static func make(p_action: Action, p_notice: Notice = Notice.NONE) -> CloudSyncPlan:
	var plan := CloudSyncPlan.new()
	plan.action = p_action
	plan.notice = p_notice
	return plan


## True when the plan changes the game on the device or tells the player.
## Only a sync that can show the player something can do it.
func needs_the_player() -> bool:
	return action == Action.USE_CLOUD or notice != Notice.NONE
