class_name AchievementServices
extends RefCounted
## Picks the achievement service of this device: Game Center on iOS, Google
## Play Games on Android, and Steam on a desktop where the Steam extension is
## in the build. When the SDK or plugin of the platform is not in the build,
## it picks [TestAchievementService], so the game runs with no service.
##
## This is only for achievements. It is not a shared platform layer.


static func for_this_device() -> AchievementService:
	var service: AchievementService = null
	if OS.has_feature("ios"):
		service = GameCenterAchievementService.new()
	elif OS.has_feature("android"):
		service = GooglePlayAchievementService.new()
	elif Engine.has_singleton(SteamAchievementService.SINGLETON):
		service = SteamAchievementService.new()
	if service == null or not service.has_sdk():
		return TestAchievementService.new()
	return service
