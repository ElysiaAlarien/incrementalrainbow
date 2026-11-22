class_name AchievementServices
extends RefCounted
## Picks the achievement service of this device: Game Center on iOS, Google
## Play Games on Android, and Steam on a desktop. When the SDK or plugin of the
## platform is not in the build, or Steam does not start, it picks
## [TestAchievementService], so the game runs with no service.
##
## This is only for achievements. [PlatformSdks] starts the SDKs that the
## achievements share with the cloud save.


## The service for an OS named [param os_name] (as [method OS.get_name]).
static func for_this_device(os_name: String = OS.get_name()) -> AchievementService:
	var service: AchievementService = null
	match os_name:
		"iOS":
			service = GameCenterAchievementService.new(GameKit.for_this_build())
		"Android":
			service = GooglePlayAchievementService.new(PlatformSdks.play_games())
		"Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			service = SteamAchievementService.new(PlatformSdks.steam())
	if service == null or not service.has_sdk():
		return TestAchievementService.new()
	return service
