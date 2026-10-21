extends GutTest
## core/save_game.gd: which saves can be read, and bringing old ones up to date.

const SaveGame := preload("res://core/save_game.gd")
const TEMP := "user://test_save_game.json" # (outside the saves folder: never in the list)


func after_each() -> void:
	DirAccess.remove_absolute(TEMP)


func test_a_current_save_reads_as_it_is() -> void:
	var data := {"version": SaveGame.VERSION, "sections": {"time": {"day": 3}}}
	assert_eq(SaveGame.upgrade(data.duplicate(true)), data)


func test_saves_older_than_the_oldest_or_from_a_newer_game_cant_be_read() -> void:
	assert_eq(SaveGame.upgrade({"version": SaveGame.OLDEST - 1}), {})
	assert_eq(SaveGame.upgrade({"version": SaveGame.VERSION + 1}), {})
	assert_eq(SaveGame.upgrade({}), {}, "no version at all")


func test_an_old_save_is_brought_up_a_version_at_a_time() -> void:
	var steps := {
		6: func(data: Dictionary) -> Dictionary:
			data["path"] += "6>7 "
			return data,
		7: func(data: Dictionary) -> Dictionary:
			data["path"] += "7>8"
			return data,
	}
	var upgraded := SaveGame.upgrade({"version": 6, "path": ""}, steps, 8, 6)
	assert_eq(upgraded["path"], "6>7 7>8")
	assert_eq(upgraded["version"], 8)


func test_a_missing_upgrade_step_means_the_save_cant_be_read() -> void:
	assert_eq(SaveGame.upgrade({"version": 6}, {}, 7, 6), {})
	assert_push_error("no upgrade step")


func test_reading_a_file_upgrades_it_and_a_damaged_one_reads_as_nothing() -> void:
	var file := FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveGame.VERSION, "clock": "Day 2"}))
	file.close()
	assert_eq(SaveGame.read(TEMP).get("clock"), "Day 2")
	file = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_eq(SaveGame.read(TEMP), {})
