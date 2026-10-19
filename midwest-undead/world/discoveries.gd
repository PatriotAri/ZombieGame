extends Node
## Places you find by going there. The map (ui/map_menu.gd) only names a place
## once you've found it (streets are always named). main.gd lists the places.
## Saved as the names found so far.

## Places found in one check (usually one; two if they're close together).
signal discovered(names: Array[String])

const CHECK_INTERVAL := 0.5

## One per place: {"name", "center": (x, z), "radius": how close counts as
## finding it, "label_at": (x, z) where the map writes its name}.
var places: Array[Dictionary] = []
var _player: Node3D
var _found := {} # name -> true
var _timer := 0.0


func setup(player: Node3D, the_places: Array[Dictionary]) -> void:
	_player = player
	places = the_places


func is_discovered(place: String) -> bool:
	return _found.has(place)


## Marks a place found without announcing it (loading, or inferring it for an
## older save).
func mark(place: String) -> void:
	_found[place] = true


func _process(delta: float) -> void:
	_timer -= delta
	if _player == null or _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	var found: Array[String] = []
	for place in places:
		var place_name: String = place["name"]
		if not _found.has(place_name) and at.distance_to(place["center"]) <= float(place["radius"]):
			_found[place_name] = true
			found.append(place_name)
	if not found.is_empty():
		discovered.emit(found)


func save_state() -> Array:
	return _found.keys()


func load_state(names: Array) -> void:
	for place_name in names:
		mark(str(place_name))
