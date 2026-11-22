class_name CloudSaveDialog
extends AcceptDialog
## Tells the player that the game on this device and the cloud save were
## different, which one the game uses, and why (ADR-0018). The other one is
## kept, and a button changes to it.
##
## It holds no rules: [method CloudSync.decide] picks the save.

## The player wants the save that the game did not pick.
signal use_other_pressed

## The width of the text on a wide screen.
const TEXT_WIDTH := 520.0

var _text := Label.new()
var _scroll: ScrollContainer
var _use_other: Button


func _init() -> void:
	name = "CloudSaveDialog"
	title = "Two different saves"
	ok_button_text = "Continue"
	# A sync can finish while another dialog shows, such as the export code.
	# Two exclusive dialogs at one time are an error.
	exclusive = false
	_text.name = "CloudSaveText"
	_text.add_theme_constant_override(&"line_spacing", 6)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll = DialogFit.wrap(self, _text)
	_use_other = add_button("Use the other game", true, "use_other")
	_use_other.name = "UseOtherSave"
	custom_action.connect(func(action: StringName) -> void:
		if action == &"use_other":
			hide()
			use_other_pressed.emit())


## Shows the conflict of [param plan] with the cloud service
## [param service_name].
func show_conflict(plan: CloudSyncPlan, service_name: String) -> void:
	_text.text = conflict_text(plan, service_name)
	DialogFit.popup(self, _scroll, TEXT_WIDTH)


## The text of the dialog, which the smoke tests read.
func text() -> String:
	return _text.text


static func conflict_text(plan: CloudSyncPlan, service_name: String) -> String:
	var this_device := "the game on this device"
	var cloud := "the game in %s" % service_name
	var used := cloud if plan.picked_cloud else this_device
	var kept := this_device if plan.picked_cloud else cloud
	return "\n".join([
		"The game on this device and the game in %s were different." % service_name,
		"The game uses the one that saved last: %s, saved %s." % [
			used, format_time(plan.used_saved_at_unix_ms)],
		"The other one, %s, saved %s, is kept. You can use it instead." % [
			kept, format_time(plan.kept_saved_at_unix_ms)],
	])


## Such as "on 2026-11-22 at 14:05", in the time zone of the device, or "at
## an unknown time" for a save with no save time.
static func format_time(unix_ms: int) -> String:
	if unix_ms == LoadResult.NO_SAVE_TIME:
		return "at an unknown time"
	@warning_ignore("integer_division")
	var local_s := unix_ms / 1000 + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var parts := Time.get_datetime_dict_from_unix_time(local_s)
	return "on %04d-%02d-%02d at %02d:%02d" % [parts.year, parts.month, parts.day, parts.hour, parts.minute]
