class_name TestAchievementService
extends AchievementService
## The test adapter: it keeps the unlocks in memory and reaches no platform.
## The game uses it when the device has no platform service, such as a build
## for a desktop with no Steam, so the game runs the same with no service.
## Tests use it to see what the game unlocks.

## The ids of the unlocked achievements, in unlock order.
var unlocked: Array[StringName] = []
## Set it to false to act as a platform that the player is not signed in to.
## Setting it to true sends [signal AchievementService.became_available].
var available := true:
	set(value):
		var became := value and not available
		available = value
		if became:
			became_available.emit()


func platform() -> StringName:
	return &"test"


func has_sdk() -> bool:
	return true


func is_available() -> bool:
	return available


func unlock(def: AchievementDef) -> bool:
	if not available:
		return false
	if not unlocked.has(def.id):
		unlocked.append(def.id)
		print_verbose("Achievement unlocked (test adapter): %s" % def.id)
	return true
