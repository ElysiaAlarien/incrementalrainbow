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
	## No warehouse has the given id.
	UNKNOWN_WAREHOUSE,
	## Warehouses are not unlocked yet in this run.
	WAREHOUSE_LOCKED,
	## The link would carry another color than the warehouse at one of its ends
	## holds.
	WRONG_COLOR,
	## The player already has the highest transport tier.
	NO_HIGHER_TIER,
	## The player's transport tier does not reach the market's remoteness.
	MARKET_TOO_REMOTE,
	## The link's vehicle is already the player's transport tier.
	VEHICLE_IS_CURRENT,
	## No lab has the given id.
	UNKNOWN_LAB,
	## There is no research with that id.
	UNKNOWN_RESEARCH,
	## The research is complete already.
	RESEARCH_COMPLETE,
	## Research that it requires is not complete.
	RESEARCH_LOCKED,
	## The percentages of a split do not add up to 100.
	SPLIT_NOT_100,
	## A percentage of a split is not a whole number from 0 to 100.
	BAD_PERCENT,
	## The command needs a link with automatic transport.
	NOT_AUTOMATIC,
	## The links of a split do not all start at one source with one color.
	MIXED_SOURCES,
	## The source of the link has no split.
	NO_SPLIT,
	## A sell threshold is not [constant WarehouseView.NO_SELL_THRESHOLD] or a
	## whole percentage of at least 1.
	BAD_SELL_THRESHOLD,
	## An automatic start sent nothing, because its warehouse holds the color
	## from the market at its end (see [method Simulation.set_sell_threshold]).
	HELD,
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
