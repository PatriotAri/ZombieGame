extends RefCounted
## Tests save into a folder of their own, emptied when they start and when
## they end, so they never touch your saves (core/save_game.gd).
const SaveGame := preload("res://core/save_game.gd")
const DIR := "user://test_saves/"


## Call first thing in a test that saves.
static func use() -> void:
	SaveGame.dir = DIR
	clear()


static func clear() -> void:
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
