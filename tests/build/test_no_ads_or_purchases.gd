extends GutTest
## The game is bought once, with no ads and no in-app purchases (#28). An ad
## or a purchase needs a plugin, an addon, a GDExtension, or a permission, so
## [StorePolicy] lets each of these into the project only from its allowlist.


func _presets(text: String) -> ConfigFile:
	var presets := ConfigFile.new()
	assert_eq(presets.parse(text), OK)
	return presets


## A preset for [param platform] that leaves out the test runner, with
## [param options].
func _preset(platform: String, options: String) -> ConfigFile:
	var preset := '[preset.0]\nname="%s"\nplatform="%s"\nexclude_filter="tests/*, addons/gut/*"\n' % [platform, platform]
	return _presets(preset + '\n[preset.0.options]\n\n' + options)


func _android(options: String) -> ConfigFile:
	return _preset("Android", options)


func _ios(options: String) -> ConfigFile:
	return _preset("iOS", options)


func test_the_project_follows_the_policy() -> void:
	assert_eq(StorePolicy.project_problems(), PackedStringArray())


func test_a_permission_that_is_off_is_not_a_problem() -> void:
	assert_eq(StorePolicy.preset_problems(_android("permissions/internet=false\n")), PackedStringArray())


func test_a_permission_that_is_not_allowed_is_a_problem() -> void:
	var problems := StorePolicy.preset_problems(_android("permissions/internet=true\n"))

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "permissions/internet")


func test_a_custom_permission_that_is_not_allowed_is_a_problem() -> void:
	var options := 'permissions/custom_permissions=PackedStringArray("com.android.vending.BILLING")\n'

	var problems := StorePolicy.preset_problems(_android(options))

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "com.android.vending.BILLING")


func test_a_plugin_that_is_not_allowed_is_a_problem() -> void:
	var problems := StorePolicy.preset_problems(_ios("plugins/InAppStore=true\n"))

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "plugins/InAppStore")


func test_an_extra_ios_capability_that_is_not_allowed_is_a_problem() -> void:
	var problems := StorePolicy.preset_problems(_ios('capabilities/additional=PackedStringArray("gamekit")\n'))

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "gamekit")


func test_extra_ios_entitlements_that_are_not_allowed_are_a_problem() -> void:
	var entitlements := "<key>com.apple.developer.in-app-payments</key><array/>"

	var problems := StorePolicy.preset_problems(_ios('entitlements/additional="%s"\n' % entitlements))

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "entitlements/additional")


func test_an_addon_that_is_not_allowed_is_a_problem() -> void:
	var problems := StorePolicy.addon_problems(PackedStringArray(["gut", "admob"]))

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "admob")


func test_a_gdextension_that_is_not_allowed_is_a_problem() -> void:
	var problems := StorePolicy.extension_problems(PackedStringArray(["res://bin/billing.gdextension"]))

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "res://bin/billing.gdextension")


func test_an_addon_that_builds_leave_out_must_be_in_each_exclude_filter() -> void:
	var presets := _presets('[preset.0]\nname="Linux"\nplatform="Linux"\nexclude_filter="tests/*"\n')

	var problems := StorePolicy.preset_problems(presets)

	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "addons/gut/*")
