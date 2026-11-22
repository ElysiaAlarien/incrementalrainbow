class_name ICloudSave
extends CloudSave
## iCloud through the iCloud key-value store (NSUbiquitousKeyValueStore) of
## the GodotApplePlugins GDExtension (commit a66f619). The calls follow the
## plugin source, and unit tests check them with a fake. No one has tested
## this on a device yet. See README.md in this folder for the steps and the
## open risk of the first download.
##
## With no plugin, [method is_available] is false and each operation finishes
## as [constant CloudOperation.Status.NOT_AVAILABLE]. The script names no
## plugin class, so it loads with no plugin.
##
## Each operation finishes at once: it uses the copy of the store on the
## device, and iCloud syncs that copy later. With no iCloud account on the
## device, the store keeps the save only on the device. The game cannot tell
## this from a sync with no change.
##
## The key-value store holds at most 1 MB for each value. The cloud save is an
## export code, which is compressed, so a large game is far below that.

## The class of the plugin.
const STORE_CLASS := &"NSUbiquitousKeyValueStore"
## The largest value that the store keeps, in bytes.
const MAX_BYTES := 1024 * 1024

## One wrapper of the store. [code]default_store()[/code] makes a new wrapper
## at each call.
var _store: Object


## [param store] is the store of the plugin, or a fake in tests. Null gets the
## store, if the build has the plugin.
func _init(store: Object = null) -> void:
	_store = store if store != null else _find_store()


func service_name() -> String:
	return "iCloud"


func is_available() -> bool:
	return _store != null


func read() -> CloudOperation:
	if _store == null:
		return CloudOperation.not_available(_not_available_message())
	# Gets the changes from iCloud that the device has.
	if not _store.call(&"synchronize"):
		return CloudOperation.failed(_cannot_sync_message())
	return CloudOperation.done(str(_store.call(&"string_for_key", SAVE_NAME)))


func write(text: String) -> CloudOperation:
	if _store == null:
		return CloudOperation.not_available(_not_available_message())
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return CloudOperation.failed("The save is too large for iCloud.")
	if not _store.call(&"set_string", text, SAVE_NAME):
		return CloudOperation.failed("iCloud did not keep the save.")
	# Tells iCloud that the store has a change.
	if not _store.call(&"synchronize"):
		return CloudOperation.failed(_cannot_sync_message())
	return CloudOperation.done()


func _not_available_message() -> String:
	return "This build has no iCloud."


func _cannot_sync_message() -> String:
	return "iCloud did not sync. The build can be without its iCloud entitlement."


static func _find_store() -> Object:
	if not ClassDB.class_exists(STORE_CLASS):
		return null
	return ClassDB.class_call_static(STORE_CLASS, &"default_store")
