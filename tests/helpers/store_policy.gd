class_name StorePolicy
extends RefCounted
## The game is bought once, with no ads and no in-app purchases (#28).
##
## An ad or a purchase needs code from outside the project: a plugin in an
## export preset, an addon, or a GDExtension. On Android it also needs a
## permission, such as com.android.vending.BILLING or AD_ID. So the project
## lets each of these in only from an allowlist below, with the reason. To add
## a plugin, such as one for cloud saves or achievements, add it to its list
## here with the reason, in the same change. See docs/building.md.

## Android permission option (permissions/<name> in a preset) to reason.
const ALLOWED_ANDROID_PERMISSIONS: Dictionary[String, String] = {}
## Android custom permission (full name) to reason.
const ALLOWED_CUSTOM_PERMISSIONS: Dictionary[String, String] = {}
## Plugin option (plugins/<name> in a preset) to reason.
const ALLOWED_PLUGINS: Dictionary[String, String] = {}
## Extra iOS device capability (capabilities/additional) to reason.
const ALLOWED_IOS_CAPABILITIES: Dictionary[String, String] = {}
## Folder in res://addons to reason.
const ALLOWED_ADDONS: Dictionary[String, String] = {
	"gut": "The test runner. The builds leave it out.",
}
## Addons that the builds leave out. Each preset must exclude them.
const ADDONS_NOT_IN_BUILDS: Array[String] = ["gut"]
## GDExtension file (res:// path) to reason.
const ALLOWED_GDEXTENSIONS: Dictionary[String, String] = {}


## The problems in the project: in res://export_presets.cfg, in res://addons,
## and in each .gdextension file.
static func project_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	var presets := ConfigFile.new()
	var error := presets.load("res://export_presets.cfg")
	if error != OK:
		problems.append("res://export_presets.cfg did not load: %s" % error_string(error))
	else:
		problems.append_array(preset_problems(presets))
	problems.append_array(addon_problems(DirAccess.get_directories_at("res://addons")))
	problems.append_array(extension_problems(_files_with_extension("res://", "gdextension")))
	return problems


## The problems in the export presets [param presets].
static func preset_problems(presets: ConfigFile) -> PackedStringArray:
	var problems := PackedStringArray()
	for section in presets.get_sections():
		if section.ends_with(".options"):
			problems.append_array(_option_problems(presets, section))
		else:
			var exclude: String = presets.get_value(section, "exclude_filter", "")
			for addon in ADDONS_NOT_IN_BUILDS:
				var filter := "addons/%s/*" % addon
				if not filter in exclude:
					problems.append("%s: exclude_filter does not have %s" % [section, filter])
	return problems


## The problems in the folders [param names] of res://addons.
static func addon_problems(names: PackedStringArray) -> PackedStringArray:
	var problems := PackedStringArray()
	for addon in names:
		if not ALLOWED_ADDONS.has(addon):
			problems.append("res://addons/%s is not in StorePolicy.ALLOWED_ADDONS" % addon)
	return problems


## The problems in the GDExtension files [param paths].
static func extension_problems(paths: PackedStringArray) -> PackedStringArray:
	var problems := PackedStringArray()
	for path in paths:
		if not ALLOWED_GDEXTENSIONS.has(path):
			problems.append("%s is not in StorePolicy.ALLOWED_GDEXTENSIONS" % path)
	return problems


static func _option_problems(presets: ConfigFile, section: String) -> PackedStringArray:
	var problems := PackedStringArray()
	for key in presets.get_section_keys(section):
		var value: Variant = presets.get_value(section, key)
		if key == "permissions/custom_permissions":
			for permission: String in value:
				if not ALLOWED_CUSTOM_PERMISSIONS.has(permission):
					problems.append("%s: %s is not in StorePolicy.ALLOWED_CUSTOM_PERMISSIONS" % [section, permission])
		elif key == "capabilities/additional":
			for capability: String in value:
				if not ALLOWED_IOS_CAPABILITIES.has(capability):
					problems.append("%s: %s is not in StorePolicy.ALLOWED_IOS_CAPABILITIES" % [section, capability])
		elif key.begins_with("permissions/") and value == true:
			if not ALLOWED_ANDROID_PERMISSIONS.has(key.trim_prefix("permissions/")):
				problems.append("%s: %s is on, but not in StorePolicy.ALLOWED_ANDROID_PERMISSIONS" % [section, key])
		elif key.begins_with("plugins/") and value == true:
			if not ALLOWED_PLUGINS.has(key.trim_prefix("plugins/")):
				problems.append("%s: %s is on, but not in StorePolicy.ALLOWED_PLUGINS" % [section, key])
	return problems


## Each file under [param dir] that ends with [param extension], except in
## .godot.
static func _files_with_extension(dir: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == extension:
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if sub == ".godot":
			continue
		found.append_array(_files_with_extension(dir.path_join(sub), extension))
	return found
