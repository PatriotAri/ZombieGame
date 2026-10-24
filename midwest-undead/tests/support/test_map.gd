extends RefCounted
## A map for a test, made in memory and never saved: world/map/map.tscn plus
## what the test adds, packed for main.gd to load like the real one. Tests
## don't depend on what's built on the real map this way.
##
##   var map := TestMap.begin()
##   var shop := TestMap.building(map, "Shop", Vector3(40, 0, 40))
##   TestMap.spawn_point(map, "trader", Vector3(0, 0.1, 12))
##   main.map_scene = TestMap.finish(map)


## The real map, to add to.
static func begin() -> Node3D:
	return load("res://world/map/map.tscn").instantiate()


## Packs the map for main.gd (main.map_scene = ...) and frees the original.
## Everything gets its save id, as saving the map in the editor does.
static func finish(map: Node3D) -> PackedScene:
	preload("res://core/save_ids.gd").assign(map)
	var packed := PackedScene.new()
	packed.pack(map)
	map.free()
	return packed


## Puts node under the map's group node called group_name (made if missing),
## owned by the map so it's packed with it.
static func add(map: Node3D, group_name: String, node: Node) -> Node:
	var group := map.get_node_or_null(group_name)
	if group == null:
		group = Node3D.new()
		group.name = group_name
		map.add_child(group)
		group.owner = map
	group.add_child(node)
	_own(node, map)
	return node


## A building with a front door and windows (its default openings), floor_y
## just above the ground.
static func building(map: Node3D, building_name: String, at: Vector3, width := 8.0, depth := 10.0,
		floors := 1) -> KitBuilding:
	var b := KitBuilding.new()
	b.name = building_name
	b.size_width = width
	b.size_depth = depth
	b.floors = floors
	b.floor_y = 0.02
	b.default_openings()
	b.position = at
	add(map, "Buildings", b)
	return b


## A SpawnPoint (person: a survivor's name, for "survivor" and "survivor_home").
static func spawn_point(map: Node3D, role: String, at: Vector3, person := "") -> KitSpawnPoint:
	var spot := KitSpawnPoint.new()
	spot.name = "%s_%s" % [role, person.replace(" ", "_")] if person != "" else role
	spot.role = role
	spot.person = person
	spot.position = at
	add(map, "Markers", spot)
	return spot


## The police station camp marker, with its Logbook, Board and Crate spots.
static func base_camp(map: Node3D, at: Vector3) -> KitBaseCamp:
	var camp := KitBaseCamp.new()
	camp.name = "StationCamp"
	camp.position = at
	for part: String in KitBaseCamp.PARTS:
		var spot := Marker3D.new()
		spot.name = part
		spot.position = KitBaseCamp.PARTS[part]
		camp.add_child(spot)
	add(map, "Markers", camp)
	return camp


## A quest marker (world/markers/quest_marker.gd).
static func quest_marker(map: Node3D, id: String, kind: String, at: Vector3) -> KitQuestMarker:
	var marker := KitQuestMarker.new()
	marker.name = id if id != "" else "QuestMarker"
	marker.marker_id = id
	marker.kind = kind
	marker.position = at
	add(map, "QuestMarkers", marker)
	return marker


## What a save calls things under a node of the loaded map (its save key and
## a "/"): picks out, say, a building's doors (main.gd moves doors out from
## under their building): d.get_meta("town_id").begins_with(TestMap.under(main, "Buildings/Shop")).
static func under(main: Node, path: String) -> String:
	return preload("res://core/save_ids.gd").key(main.town.get_node(path), main.town) + "/"


## Local z of the middle of a building's ground-floor front door (0 if none).
static func front_door_z(b: Node) -> float:
	for op in b.openings:
		if op and op.kind == "door" and b.edge_of(op) == 0 and op.level == 0:
			return op.offset
	return 0.0


static func _own(node: Node, map: Node) -> void:
	node.owner = map
	for child in node.get_children():
		_own(child, map)
