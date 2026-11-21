extends GutHookScript
## Makes the run fail when GUT silently skips work.
##
## GUT ignores a test script that does not parse and still exits with 0, and
## it exits with 0 when no test ran. Both would hide breakage in CI.

const TEST_ROOT := "res://tests/"
const TEST_PREFIX := "test_"
const TEST_SUFFIX := ".gd"


func run() -> void:
	var collected := {}
	for script in gut.get_test_collector().scripts:
		collected[script.path] = true

	var problems: PackedStringArray = []
	for path in _find_test_files(TEST_ROOT):
		if not collected.has(path):
			problems.append("Test script was not loaded (parse error?): %s" % path)
	if gut.get_test_count() == 0:
		problems.append("No tests ran.")

	for problem in problems:
		gut.logger.error(problem)
	if not problems.is_empty():
		set_exit_code(1)


func _find_test_files(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir_path):
		if file.begins_with(TEST_PREFIX) and file.ends_with(TEST_SUFFIX):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_find_test_files(dir_path.path_join(sub)))
	return found
