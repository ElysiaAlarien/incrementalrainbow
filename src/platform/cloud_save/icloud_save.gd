class_name ICloudSave
extends CloudSave
## iCloud through the iCloud key-value store (NSUbiquitousKeyValueStore) of
## the GodotApplePlugins GDExtension. NOT FINISHED: the game does not ship the
## plugin yet, and no one has tested this on a device. See README.md in this
## folder for the steps.
##
## With no plugin, [method is_available] is false and each operation finishes
## as [constant CloudOperation.Status.NOT_AVAILABLE]. The script names no
## plugin class, so it loads with no plugin.
##
## The key-value store holds at most 1 MB for each value. The cloud save is an
## export code, which is compressed, so a large game is far below that.

## The class of the plugin.
const STORE_CLASS := &"NSUbiquitousKeyValueStore"
## The largest value that the store keeps, in bytes.
const MAX_BYTES := 1024 * 1024


func service_name() -> String:
	return "iCloud"


func is_available() -> bool:
	return _store() != null


func read() -> CloudOperation:
	var store := _store()
	if store == null:
		return CloudOperation.not_available(_not_available_message())
	# Gets the changes from iCloud that the device has.
	store.call(&"synchronize")
	return CloudOperation.done(str(store.call(&"string_for_key", SAVE_NAME)))


func write(text: String) -> CloudOperation:
	var store := _store()
	if store == null:
		return CloudOperation.not_available(_not_available_message())
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return CloudOperation.failed("The save is too large for iCloud.")
	if not store.call(&"set_string", text, SAVE_NAME):
		return CloudOperation.failed("iCloud did not keep the save.")
	store.call(&"synchronize")
	return CloudOperation.done()


func _not_available_message() -> String:
	return "This build has no iCloud."


static func _store() -> Object:
	if not ClassDB.class_exists(STORE_CLASS):
		return null
	return ClassDB.class_call_static(STORE_CLASS, &"default_store")
