extends SceneTree
## Building tools phase 2: inner walls split a floor into rooms; doorways,
## doors and windows go in them (inner ones can't be boarded); a painted room's
## floor and walls take its materials and stop at its walls; the navigation
## goes through doorways.
const KitBuilding := preload("res://world/building.gd")
var main: Node
var f := 0
var house: Node3D
var baked_at := -1
var fails := 0
var base := Vector3(-110, 0, -70)
var tile: Material
var paper: Material

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(house.global_transform * a, house.global_transform * b)
	return root.get_world_3d().direct_space_state.intersect_ray(q)

## Every vertex (house space) drawn in material m.
func drawn_in(m: Material) -> PackedVector3Array:
	var found := PackedVector3Array()
	for mi in house.find_children("*", "MeshInstance3D", true, false) + house.get_children(true).filter(func(n): return n is StaticBody3D).map(func(b): return b.get_children(true)).reduce(func(a, b): return a + b, []).filter(func(n): return n is MeshInstance3D):
		var mesh: Mesh = mi.mesh
		if mesh == null: continue
		for i in mesh.get_surface_count():
			if mesh.surface_get_material(i) == m:
				found.append_array(mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return found

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
		main.player.set_physics_process(false)
		tile = load("res://world/kit/materials/concrete_slab.tres")
		paper = load("res://world/kit/materials/siding_blue.tres")
		house = KitBuilding.new()
		house.position = base
		house.size_depth = 12.0
		house.size_width = 10.0
		house.floor_y = 0.02
		house.default_openings()
		# Across the middle: a front room and a back room, a doorway between.
		var middle := KitInnerWall.make(0, Vector2(6, -5), Vector2(6, 5))
		var doorway: Array[KitOpening] = [KitOpening.make("front", "doorway", 0.0, 1.6, 0.0, 2.4)]
		middle.openings = doorway
		# The back room split again, with a door and a window in that wall.
		var back := KitInnerWall.make(0, Vector2(6, 1), Vector2(12, 1))
		var door_and_window: Array[KitOpening] = [KitOpening.make("front", "door", -1.0, 1.6, 0.0, 2.4), KitOpening.make("front", "window", 1.6, 1.0, 0.9, 2.0)]
		back.openings = door_and_window
		var walls: Array[KitInnerWall] = [middle, back]
		house.inner_walls = walls
		var front_room := KitRoom.make(0, Vector2(3, 0))
		front_room.floor_material = tile
		front_room.wall_material = paper
		var marked: Array[KitRoom] = [front_room]
		house.rooms = marked
		main.nav_region.add_child(house)
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		main.fortifications.rebake()
	if f == 5:
		check(house._get_configuration_warnings().is_empty(), "no warnings (%s)" % [house._get_configuration_warnings()])
		check(house.room_at(0, Vector2(3, 2)) == house.rooms[0] and house.room_at(0, Vector2(9, -2)) == null and house.room_at(0, Vector2(9, 3)) == null,
				"the front room is marked; the two back ones aren't")
		# Through the doorway, and into the wall beside it.
		check(ray(Vector3(3, 1.0, 0), Vector3(9, 1.0, 0)).is_empty() or ray(Vector3(3, 1.0, 0), Vector3(9, 1.0, 0))["position"].distance_to(house.global_transform * Vector3(6, 1, 0)) > 0.5, "the doorway is open")
		check(not ray(Vector3(3, 1.0, 3), Vector3(9, 1.0, 3)).is_empty(), "the wall beside it is solid")
		var names: Array = house.get_children(true).map(func(n): return str(n.name))
		check("Inner2Door" in names and "Inner2Window" in names, "a door and a window in the inner wall (%s)" % [names.filter(func(n): return n.begins_with("Inner"))])
		var door = house.get_node("Inner2Door")
		check(not door.boardable and not house.get_node("Inner2Window").boardable, "inner ones can't be boarded up")
		var floor_verts := Array(drawn_in(tile)).filter(func(v): return absf(v.y - 0.02) < 0.01)
		check(floor_verts.size() > 0 and floor_verts.all(func(v): return v.x <= 6.01), "the front room's floor is tiled, and only there (%d corners, x up to %.2f)" % [floor_verts.size(), floor_verts.map(func(v): return v.x).max() if floor_verts.size() else -1.0])
		var paper_verts := Array(drawn_in(paper))
		check(paper_verts.size() > 0 and paper_verts.all(func(v): return v.x <= 6.15), "its walls are papered, and only its walls (x up to %.2f)" % (paper_verts.map(func(v): return v.x).max() if paper_verts.size() else -1.0))
		var paper_z: Array = paper_verts.map(func(v): return v.z)
		check(paper_z.min() < -4.5 and paper_z.max() > 4.5, "...side walls too, as far as the inner wall")
		check(house.get_node("FrontDoor") != null and house.get_node("FrontDoor").boardable, "the front door is still boardable")
	if baked_at > 0 and f == baked_at + 70:
		var map: RID = main.get_world_3d().navigation_map
		var from: Vector3 = house.global_transform * Vector3(3.0, 0.05, 3.0)
		var to: Vector3 = house.global_transform * Vector3(10.0, 0.05, -3.0)
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var end: Vector3 = path[path.size() - 1] if path.size() else Vector3.INF
		var through := Array(path).any(func(p): var l: Vector3 = house.to_local(p); return absf(l.x - 6.0) < 1.0 and absf(l.z) < 0.8)
		print("    path: ", Array(path).map(func(p): return house.to_local(p).snappedf(0.1)))
		check(end.distance_to(to) < 0.6 and through, "a path from the front room through the doorway to the back (%d points)" % path.size())
		print("FAILS: %d" % fails)
		return true
	return f > 1500
