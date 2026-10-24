extends SceneTree
## Props set up before they're in the tree (every building's windows and doors
## and every piece of furniture on a map: main.gd builds them before the map
## goes in) still get their paint, their view distance and their collision once
## their look comes. On a test map with a shop and some furniture.
const TestMap := preload("res://tests/support/test_map.gd")
var main: Node
var f := 0
var fails := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	var map := TestMap.begin()
	var shop := TestMap.building(map, "Shop", Vector3(40, 0, 40))
	var x := -10.0
	for scene in ["counter", "car", "dumpster", "bed"]:
		var piece: Node3D = load("res://world/kit/furniture/%s.tscn" % scene).instantiate()
		piece.name = scene.capitalize()
		if scene == "counter":
			piece.position = Vector3(3, 0.02, 2)
			shop.add_child(piece)
			TestMap._own(piece, map)
		else:
			piece.position = Vector3(x, 0.0, -8)
			x -= 8.0
			TestMap.add(map, "Props", piece)
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = TestMap.finish(map)
	root.add_child(main)

func limited(prop: KitProp, meters: float) -> bool:
	return not prop.meshes().is_empty() and prop.meshes().all(func(m: MeshInstance3D) -> bool:
		return m.is_in_group(&"view_limited") and is_equal_approx(float(m.get_meta("view_meters")), meters))

func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		const ViewDistance := preload("res://core/view_distance.gd")
		for path in ["Buildings/Shop/Counter", "Props/Car", "Props/Dumpster", "Props/Bed"]:
			var piece: Node = main.town.get_node(path)
			var prop: KitProp = piece.find_children("*", "KitProp", true, false)[0]
			var paints: Array = prop.meshes().filter(func(m: MeshInstance3D) -> bool: return m.name.begins_with("Paint"))
			check(not paints.is_empty() and paints.all(func(m: MeshInstance3D) -> bool: return m.material_override == piece.material),
					"%s: painted in its material" % path)
			check(limited(prop, ViewDistance.meters_for_size(piece.size)), "%s: drawn to %.0f m" % [path, ViewDistance.meters_for_size(piece.size)])
			check(piece.find_children("*", "CollisionShape3D", false, false).size() == 1, "%s: solid (its box: the stand-in brings no shapes)" % path)
		var window: Node = main.windows[0]
		check(limited(window._look, window.VIEW_METERS), "a window: drawn to %.0f m" % window.VIEW_METERS)
		var door: Node = main.doors[0]
		check(limited(door._look, door.VIEW_METERS), "a door: drawn to %.0f m" % door.VIEW_METERS)
		print("FAILS: %d" % fails)
		return true
	return false
