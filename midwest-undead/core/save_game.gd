extends RefCounted
## Reading and writing the save file. Never instanced.
##
## How loading works: the town is generated from a fixed seed, so it comes out
## identical every time. Loading therefore just reloads the scene (rebuilding
## the town from scratch) and then main.gd applies the saved changes on top:
## where you are, what you carry, what's been looted, which zombies and bandits
## are still up, the time of day, and how far the story has got.
##
## The file is JSON in Godot's user:// folder. To find it, use
## Project > Open User Data Folder in the editor.

const PATH := "user://savegame.json"
const VERSION := 2 # bump whenever the save layout changes; older saves are ignored

## Set by request_load(); main.gd picks it up after the scene reloads.
static var pending_load: Dictionary = {}


## True if there's a save file that can actually be loaded (right version, not damaged).
static func exists() -> bool:
	return FileAccess.file_exists(PATH) and not read().is_empty()


static func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't write save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != VERSION:
		push_warning("Save file is missing, damaged, or from an older version; ignoring it.")
		return {}
	return parsed


## Reload the world and restore the save. Returns false if there's no usable save.
static func request_load(tree: SceneTree) -> bool:
	var data := read()
	if data.is_empty():
		return false
	pending_load = data
	tree.paused = false # pause survives a scene reload, so clear it first
	tree.reload_current_scene()
	return true


## Vector3 <-> plain arrays, since JSON has no vector type.
static func vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
