extends Node
## What quests can point at in the world, by id: the map's quest markers
## (world/markers/quest_marker.gd) and people with an npc_id (HumanNPC). It
## also watches the area markers and reports when you come into one or leave
## it (area_entered, area_left: core/game_events.gd). main.gd makes it.

const GameEvents := preload("res://core/game_events.gd")

const CHECK_INTERVAL := 0.25

var _markers := {} # marker id -> KitQuestMarker
var _areas: Array[KitQuestMarker] = []
var _inside := {} # area marker id -> true while you're in it
var _player: Node3D
var _timer := 0.0
var _settled := false # the first check after setup or a load only notes where you are


func _ready() -> void:
	add_to_group("quest_world")


## map: the map scene. Finds its quest markers, warning about missing or
## repeated ids.
func setup(map: Node, player: Node3D) -> void:
	_player = player
	for node in map.find_children("*", "Marker3D", true, false):
		if not node is KitQuestMarker:
			continue
		var marker := node as KitQuestMarker
		if marker.marker_id == "":
			push_warning("A quest marker (%s) has no Marker Id." % marker.get_path())
			continue
		if _markers.has(marker.marker_id):
			push_warning("Two quest markers are called \"%s\"; quests use the first." % marker.marker_id)
			continue
		_markers[marker.marker_id] = marker
		if marker.kind == "area":
			_areas.append(marker)


## The quest marker with this id, or null.
func marker(id: String) -> KitQuestMarker:
	return _markers.get(id)


func marker_ids() -> Array:
	return _markers.keys()


## The person with this npc_id, alive or dead, or null if there's nobody by it
## (yet: some people only turn up partway through).
func npc(id: String) -> HumanNPC:
	if id == "":
		return null
	for node in get_tree().get_nodes_in_group("named_npcs"):
		if (node as HumanNPC).npc_id == id:
			return node
	return null


## Whether you're in an area marker right now.
func is_inside(id: String) -> bool:
	return _inside.has(id)


## Lets a usable marker be used (or not), for a quest that wants it.
func set_usable(id: String, on: bool) -> void:
	var m := marker(id)
	if m:
		m.usable = on


## After loading a save: where you are now isn't you arriving anywhere.
func resettle() -> void:
	_settled = false
	_timer = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _player == null or _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var at := _player.global_position
	for area in _areas:
		var id := area.marker_id
		var now := area.contains(at)
		if now == _inside.has(id):
			continue
		if now:
			_inside[id] = true
		else:
			_inside.erase(id)
		if _settled:
			GameEvents.send(&"area_entered" if now else &"area_left", {"marker": id})
	_settled = true
