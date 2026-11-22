class_name CloudSave
extends RefCounted
## The one interface between the game and a platform cloud save: Steam Cloud,
## iCloud, or Google Play (see ADR-0018). It is outside the core, and it knows
## nothing about the text that it keeps: [CloudSaveSession] gives it an
## export code ([ExportCode]) and decides what to do with what it reads.
##
## This class is also the adapter for a device with no cloud save. Each
## operation finishes at once as [constant CloudOperation.Status.NOT_AVAILABLE],
## so the game saves only on the device. An adapter extends this class and
## overrides each method. An adapter must never stop the game: when its SDK or
## plugin is not there, it acts as this class does.

## The name of the save in each cloud. Each platform keeps one save.
const SAVE_NAME := "incremental_rainbow_save"


## The name of the service for the player, for example "Steam Cloud".
func service_name() -> String:
	return "cloud save"


## True when the service is on this device and can work now: its SDK or
## plugin is there, and the player is signed in and lets the game use it. A
## read or a write can still fail, for example with no network.
func is_available() -> bool:
	return false


## Reads the cloud save. A good answer has the save text, or an empty text
## when the cloud has no save.
func read() -> CloudOperation:
	return CloudOperation.not_available(_not_available_message())


## Replaces the cloud save with [param text].
func write(_text: String) -> CloudOperation:
	return CloudOperation.not_available(_not_available_message())


func _not_available_message() -> String:
	return "This device has no %s." % service_name()
