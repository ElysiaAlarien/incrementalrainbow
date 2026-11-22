extends SceneTree
## Writes tests/fixtures/query_results.json: the hashes of the market and
## forecast queries in the game of [QueryResults]. Run it only when a change
## of the rules is meant to change the results, and say so in the PR.
##
## Usage: godot --headless -s res://tools/make_query_results.gd


func _init() -> void:
	var file := FileAccess.open(QueryResults.FIXTURE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(QueryResults.record(), "\t", false) + "\n")
	file.close()
	print("Wrote %s." % QueryResults.FIXTURE_PATH)
	quit()
