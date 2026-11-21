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
	## The color has a recipe, so a base factory cannot make it.
	NOT_A_BASE_COLOR,
	## No factory has the given id.
	UNKNOWN_FACTORY,
	## The player has less money than the command costs.
	NOT_ENOUGH_MONEY,
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
