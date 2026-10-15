extends RefCounted
## Reading and writing saves. Never instanced.
##
## How loading works: the town is a scene (world/town/town.tscn), the same every
## time. Loading therefore just reloads the game scene (loading the town fresh)
## and then main.gd applies the saved changes on top:
## where you are, what you carry, what's been looted, which zombies and bandits
## are still up, the time of day, and how far the story has got.
##
## Every save is its own JSON file in user://saves/: save_1.json, save_2.json...
## for the ones you make at the logbook, and autosave.json, which the game
## overwrites when it autosaves. To find them, use Project > Open User Data
## Folder in the editor.

const DIR := "user://saves/"
const AUTOSAVE := DIR + "autosave.json"
const OLD_PATH := "user://savegame.json" # before there was a list: becomes save_1
const GAME_SCENE := "res://world/main.tscn"
const VERSION := 4 # bump whenever the save layout changes; older saves are ignored (4: the new map)

## Set by request_load(); main.gd picks it up after the scene reloads.
static var pending_load: Dictionary = {}


## True if there's at least one save that can be loaded.
static func exists() -> bool:
	return not list().is_empty()


## Every save that can be loaded, newest first: {"path", "autosave": bool,
## "title": "Day 3, 7:40 PM", "detail": the objective and when it was saved}.
static func list() -> Array[Dictionary]:
	_move_old_save()
	var saves: Array[Dictionary] = []
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".json"):
			continue
		var path := DIR + file
		var data := read(path)
		if data.is_empty():
			continue
		var autosave := path == AUTOSAVE
		saves.append({
			"path": path,
			"autosave": autosave,
			"saved_unix": float(data.get("saved_unix", 0.0)),
			"title": ("Autosave  ·  " if autosave else "") + str(data.get("clock", "?")),
			"detail": "%s\nSaved %s" % [data.get("objective", ""), _when(str(data.get("saved_at", "")))],
		})
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["saved_unix"] > b["saved_unix"])
	return saves


## The newest save's path, or "" if there isn't one.
static func latest() -> String:
	var saves := list()
	return saves[0]["path"] if not saves.is_empty() else ""


## A path for a new save (the next unused number).
static func new_path() -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var n := 1
	while FileAccess.file_exists(DIR + "save_%d.json" % n):
		n += 1
	return DIR + "save_%d.json" % n


static func write(data: Dictionary, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	data["version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	data["saved_unix"] = Time.get_unix_time_from_system() # sorts the list (finer than saved_at)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't write save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != VERSION:
		return {} # damaged, or from an older version of the game
	return parsed


static func delete(path: String) -> void:
	if path.begins_with(DIR):
		DirAccess.remove_absolute(path)


## Load the world fresh (from the game or the main menu) and restore a save:
## the one at `path`, or the newest if path is "". Returns false if there's no
## usable save.
static func request_load(tree: SceneTree, path := "") -> bool:
	if path == "":
		path = latest()
	var data := read(path)
	if data.is_empty():
		return false
	pending_load = data
	tree.paused = false # pause survives a scene change, so clear it first
	tree.change_scene_to_file(GAME_SCENE)
	return true


## Vector3 <-> plain arrays, since JSON has no vector type.
static func vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## "2026-10-13 14:02:33" -> "Oct 13, 14:02".
static func _when(stamp: String) -> String:
	var parts := stamp.split(" ")
	if parts.size() < 2:
		return stamp
	var date := parts[0].split("-")
	if date.size() < 3:
		return stamp
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [MONTHS[clampi(int(date[1]) - 1, 0, 11)], int(date[2]), parts[1].substr(0, 5)]


## The single save file from before saves were a list joins the list.
static func _move_old_save() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	if FileAccess.file_exists(OLD_PATH):
		DirAccess.rename_absolute(OLD_PATH, new_path())
