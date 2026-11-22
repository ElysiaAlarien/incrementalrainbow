class_name AchievementService
extends RefCounted
## The one achievement interface (ADR-0019): it tells one platform's service
## that the player earned an achievement. Each platform has an adapter that
## extends this script. [AchievementServices] picks the adapter of the device.
##
## An adapter must not stop the game. With no SDK, no sign-in, or no network,
## [method unlock] returns false and does nothing else. [AchievementTracker]
## then tries again when [signal became_available] comes, and at the next
## start of the game.

## Sent when [method is_available] becomes true, for example when the player
## signs in.
signal became_available


## The key of this platform in "platform_ids" of data/achievements.json, such
## as [code]&"steam"[/code].
func platform() -> StringName:
	return &""


## True when the SDK or plugin of the platform is in this build.
func has_sdk() -> bool:
	return false


## True when [method unlock] can reach the platform now.
func is_available() -> bool:
	return false


## Tells the platform that the player earned [param def]. Returns true when
## the platform took it. The platform keeps each unlock, so a second unlock of
## the same achievement changes nothing there.
func unlock(_def: AchievementDef) -> bool:
	return false


## The game calls this once each frame, for an SDK that needs it.
func poll() -> void:
	pass
