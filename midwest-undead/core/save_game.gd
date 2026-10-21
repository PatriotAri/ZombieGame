extends RefCounted
## Reading and writing saves. Never instanced.
##
## How loading works: the map is a scene (world/map/map.tscn), the same every
## time. Loading therefore just reloads the game scene (loading the map fresh)
## and then main.gd applies the saved changes on top (world/save_io.gd):
## where you are, what you carry, what's been looted, which zombies and bandits
## are still up, the time of day, and how far the story has got.
##
## Versions: every save says which VERSION of the layout it has. A save from
## an older one is brought up to date as it's read, one version at a time
## (_upgrades()); one older than OLDEST, or from a newer game, can't be read
## and doesn't show in the list.
##
## Every save is its own JSON file in user://saves/: save_1.json, save_2.json...
## for the ones you make at the logbook (each can have a name you give it), and
## autosave.json, which the game overwrites when it autosaves. To find them, use Project > Open User Data
## Folder in the editor.

const DIR := "user://saves/"
const AUTOSAVE := DIR + "autosave.json"
const OLD_PATH := "user://savegame.json" # before there was a list: becomes save_1
const GAME_SCENE := "res://world/main.tscn"
const SceneFade := preload("res://ui/scene_fade.gd")
const NAME_LENGTH := 40 # characters a save's name can have
## The save layout. Change the layout: add one to it, and add the step that
## brings the version before up to date to _upgrades().
## (5: base camps; 6: things on the map saved by their save IDs, systems in sections.)
const VERSION := 6
## The oldest layout that can still be read. 5 and before can't: they found
## things on the map by where they were in the map scene.
const OLDEST := 6

## Set by request_load(); main.gd picks it up after the scene reloads.
static var pending_load: Dictionary = {}


## True if there's at least one save that can be loaded.
static func exists() -> bool:
	return not list().is_empty()


## Every save that can be loaded, newest first: {"path", "autosave": bool,
## "name": what you called it ("" if nothing), "title": its name, or
## "Day 3, 7:40 PM", "detail": the objective and when it was saved}.
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
		var save_name := str(data.get("name", ""))
		var clock := str(data.get("clock", "?"))
		saves.append({
			"path": path,
			"autosave": autosave,
			"name": save_name,
			"saved_unix": float(data.get("saved_unix", 0.0)),
			"title": ("Autosave  ·  " if autosave else "") + (save_name if save_name != "" else clock),
			"detail": "%s%s\nSaved %s" % [clock + "  ·  " if save_name != "" else "", data.get("objective", ""),
					_when(str(data.get("saved_at", "")))],
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


## Names a save (or, with "", takes its name away). Everything else in it,
## when it was saved included, stays as it was. False if it couldn't.
static func rename(path: String, save_name: String) -> bool:
	var data := read(path)
	if data.is_empty() or path == AUTOSAVE:
		return false
	save_name = clean_name(save_name)
	if save_name == "":
		data.erase("name")
	else:
		data["name"] = save_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## A save's name as it's kept: one line, no spaces at the ends, at most NAME_LENGTH long.
static func clean_name(save_name: String) -> String:
	return save_name.replace("\n", " ").replace("\t", " ").strip_edges().left(NAME_LENGTH)


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new() # (parse_string() would print an error for every damaged save)
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {} # damaged
	return upgrade(json.data)


## data brought up to the current VERSION, a step at a time; {} if it can't
## be (older than OLDEST, from a newer game, or a step is missing). steps,
## newest and oldest are for tests: the game uses its own.
static func upgrade(data: Dictionary, steps := _upgrades(), newest := VERSION, oldest := OLDEST) -> Dictionary:
	var version := int(data.get("version", 0))
	if version < oldest or version > newest:
		return {}
	while version < newest:
		var step: Callable = steps.get(version, Callable())
		if not step.is_valid():
			push_error("Saves of version %d can't be brought up to date: no upgrade step." % version)
			return {}
		data = step.call(data)
		version += 1
		data["version"] = version
	return data


## version -> the step that turns a save of that version into one of the next:
## a static func (data: Dictionary) -> Dictionary. None yet.
## e.g. {6: _from_6} with
##     static func _from_6(data: Dictionary) -> Dictionary:
##         data["sections"]["player"]["stamina"] = 100.0 # (what changed in 7)
##         return data
static func _upgrades() -> Dictionary:
	return {}


static func delete(path: String) -> void:
	if path.begins_with(DIR):
		DirAccess.remove_absolute(path)


## Load the world fresh (from the game or the main menu) and restore a save:
## the one at `path`, or the newest if path is "". Returns false if there's no
## usable save.
static func request_load(tree: SceneTree, path := "") -> bool:
	if SceneFade.busy(tree):
		return true # already on the way somewhere (a second press during the fade)
	if path == "":
		path = latest()
	var data := read(path)
	if data.is_empty():
		return false
	pending_load = data
	SceneFade.change_to(tree, GAME_SCENE)
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
