class_name CommandResult
extends RefCounted
## The result of a simulation command.
##
## A command that is not allowed returns [code]ok == false[/code] with a
## [member reason] and a readable [member message], and does not change the
## simulation state.

enum Reason {
	NONE,
	## The color id is not in the content.
	UNKNOWN_COLOR,
	## The color is not unlocked yet, for example because it needs research.
	COLOR_LOCKED,
	## No factory has the given id.
	UNKNOWN_FACTORY,
	## The player has less money than the command costs.
	NOT_ENOUGH_MONEY,
	## There is no market with that id.
	UNKNOWN_MARKET,
	## A link from that factory to that destination already exists.
	LINK_EXISTS,
	## The destination factory's recipe does not use the link's color.
	NOT_A_RECIPE_INPUT,
	## There is no link with that id.
	UNKNOWN_LINK,
	## The shipment would carry no widgets: the source has none, or the
	## destination accepts none, such as a market with no capacity left in the
	## current period.
	NOTHING_TO_SHIP,
	## The link already has automatic transport.
	ALREADY_AUTOMATIC,
	## A prestige needs at least one prism.
	NO_PRISMS,
}

var ok: bool
var reason: Reason
## Text for the player or a log. Do not branch on it; use [member reason].
var message: String
## What the command made, if anything. For example, the id of a new factory.
var value: Variant


static func success(p_value: Variant = null) -> CommandResult:
	var result := CommandResult.new()
	result.ok = true
	result.reason = Reason.NONE
	result.value = p_value
	return result


static func failure(p_reason: Reason, p_message: String) -> CommandResult:
	var result := CommandResult.new()
	result.ok = false
	result.reason = p_reason
	result.message = p_message
	return result
