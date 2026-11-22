class_name OfflineSummaryDialog
extends AcceptDialog
## Tells the player what happened while they were away: the time away, the
## money earned, the widgets sold, and the widgets made, and when the time
## away was more than offline progress applies. It holds no rules:
## [method Simulation.progress_offline] makes the summary.
##
## When more offline progress comes while the dialog is open, such as when a
## phone game goes to the background again, the dialog adds it to the summary
## that it shows.

## The width of the text on a wide screen.
const TEXT_WIDTH := 460.0

var _summary: OfflineSummary
var _text := Label.new()
var _scroll: ScrollContainer


func _init() -> void:
	name = "OfflineSummaryDialog"
	title = "Welcome back"
	ok_button_text = "Continue"
	_text.name = "OfflineSummaryText"
	_text.add_theme_constant_override(&"line_spacing", 6)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll = DialogFit.wrap(self, _text)
	visibility_changed.connect(func() -> void:
		if not visible:
			_summary = null)


## Shows [param summary], added to the summary that the dialog shows now, if
## it is open. [param max_offline_ms] is the most time away that offline
## progress applies.
func show_summary(summary: OfflineSummary, max_offline_ms: int) -> void:
	if _summary == null:
		_summary = OfflineSummary.new()
	_summary.add(summary)
	_text.text = summary_text(_summary, max_offline_ms)
	DialogFit.popup(self, _scroll, TEXT_WIDTH)


## The text of the dialog, which the smoke tests read.
func text() -> String:
	return _text.text


static func summary_text(summary: OfflineSummary, max_offline_ms: int) -> String:
	var lines := PackedStringArray([
		"You were away for %s." % format_duration(summary.duration_ms + summary.skipped_ms)])
	if summary.skipped_ms > 0:
		lines.append("Offline progress stops at %s, so the game advanced %s." % [
			format_duration(max_offline_ms), format_duration(summary.duration_ms)])
	lines.append_array([
		"Money earned: %s" % summary.money_earned.format(),
		"Widgets sold: %s" % BigNumber.from_int(summary.widgets_sold).format(),
		"Widgets made: %s" % BigNumber.from_int(summary.widgets_made).format(),
	])
	return "\n".join(lines)


## Such as "45 s", "12 min", "3 h 5 min", "24 h", or "2 d 4 h": the two
## largest units, in hours up to 48 h.
static func format_duration(duration_ms: int) -> String:
	@warning_ignore("integer_division")
	var seconds := duration_ms / 1000
	if seconds < 60:
		return "%d s" % seconds
	@warning_ignore("integer_division")
	var minutes := seconds / 60
	if minutes < 60:
		return "%d min" % minutes
	@warning_ignore("integer_division")
	var hours := minutes / 60
	if hours < 48:
		return "%d h" % hours if minutes % 60 == 0 else "%d h %d min" % [hours, minutes % 60]
	@warning_ignore("integer_division")
	var days := hours / 24
	return "%d d" % days if hours % 24 == 0 else "%d d %d h" % [days, hours % 24]
