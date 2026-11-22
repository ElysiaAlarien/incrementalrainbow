extends GutTest
## The export presets in export_presets.cfg (#28). See docs/building.md.

## Preset name to Godot platform name, one preset for each store platform.
const PLATFORMS := {
	"Linux": "Linux",
	"Windows": "Windows Desktop",
	"macOS": "macOS",
	"iOS": "iOS",
	"Android": "Android",
}
## Keys whose value is a secret. Godot keeps these in
## .godot/export_credentials.cfg, which git ignores, or reads them from
## environment variables.
const SECRET_KEYS := [
	"keystore/debug",
	"keystore/debug_user",
	"keystore/debug_password",
	"keystore/release",
	"keystore/release_user",
	"keystore/release_password",
	"codesign/identity",
	"codesign/password",
	"codesign/certificate_file",
	"codesign/certificate_password",
	"codesign/provisioning_profile",
	"notarization/api_key",
	"notarization/api_key_id",
	"notarization/api_uuid",
	"notarization/apple_id_name",
	"notarization/apple_id_password",
	"application/provisioning_profile_uuid_debug",
	"application/provisioning_profile_uuid_release",
	"application/provisioning_profile_specifier_debug",
	"application/provisioning_profile_specifier_release",
]

var _presets := ConfigFile.new()


func before_all() -> void:
	assert_eq(_presets.load("res://export_presets.cfg"), OK)


func _sections() -> PackedStringArray:
	var sections := PackedStringArray()
	for section in _presets.get_sections():
		if not section.ends_with(".options"):
			sections.append(section)
	return sections


func test_each_store_platform_has_one_preset() -> void:
	var found := {}
	for section in _sections():
		found[_presets.get_value(section, "name")] = _presets.get_value(section, "platform")

	assert_eq(found, PLATFORMS)


func test_each_build_goes_to_the_build_folder() -> void:
	for section in _sections():
		var path: String = _presets.get_value(section, "export_path", "")
		assert_true(path.begins_with("build/"), "%s exports to %s" % [section, path])


func test_each_build_has_the_content_and_not_the_tests() -> void:
	for section in _sections():
		var include: String = _presets.get_value(section, "include_filter", "")
		var exclude: String = _presets.get_value(section, "exclude_filter", "")
		assert_string_contains(include, "data/*.json")
		for folder in ["tests/*", "tools/*", "docs/*", "build/*"]:
			assert_string_contains(exclude, folder)


func test_the_presets_have_no_secrets() -> void:
	for section in _presets.get_sections():
		if not section.ends_with(".options"):
			continue
		for key in SECRET_KEYS:
			var value: Variant = _presets.get_value(section, key, "")
			assert_eq(str(value), "", "%s %s must be empty" % [section, key])
