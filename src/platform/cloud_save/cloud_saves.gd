class_name CloudSaves
extends RefCounted
## Picks the [CloudSave] adapter for this device.
##
## - [code]--test-cloud-save=<folder>[/code] after [code]--[/code] on the
##   command line: a [TestCloudSave] in that folder.
## - iOS: [ICloudSave]. Android: [GooglePlayCloudSave].
## - Windows, macOS, and Linux: [SteamCloudSave].
## - Any other device: [CloudSave], which has no cloud.
## An adapter whose SDK or plugin is not in the build is not available, so the
## game saves only on the device.

const TEST_FOLDER_ARG := "--test-cloud-save="


## The adapter for an OS named [param os_name] (as [method OS.get_name]) and
## the user arguments [param args] (as [method OS.get_cmdline_user_args]).
static func for_device(os_name: String = OS.get_name(),
		args: PackedStringArray = OS.get_cmdline_user_args()) -> CloudSave:
	for arg in args:
		if arg.begins_with(TEST_FOLDER_ARG):
			return TestCloudSave.new(arg.trim_prefix(TEST_FOLDER_ARG))
	match os_name:
		"iOS":
			return ICloudSave.new()
		"Android":
			return GooglePlayCloudSave.new()
		"Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return SteamCloudSave.new()
	return CloudSave.new()
