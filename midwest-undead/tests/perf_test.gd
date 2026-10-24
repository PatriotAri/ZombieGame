extends SceneTree
## Performance: stand-ins flattened (same size, fewer meshes), the same looks
## batched (GPU instancing) and leaving their batch when they change, merged
## meshes keeping their colors, buildings hiding what's behind them
## (occluders), and the setting that turns that off.
const Settings := preload("res://core/settings.gd")
var main: Node
var f := 0
var fails := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	var town = load("res://tests/support/stress_town.gd")
	town.COLS = 4
	town.ROWS = 3
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = town.make(self)
	root.add_child(main)

func batched(node: Node) -> bool:
	return node.find_children("*", "MeshInstance3D", true, false).any(func(m): return m.has_meta(&"batched"))

func shown(node: Node) -> bool:
	return node.find_children("*", "MeshInstance3D", true, false).any(func(m): return m.is_visible_in_tree())

func _physics_process(_d: float) -> bool:
	f += 1
	if f != 5:
		return false
	main.player.set_physics_process(false)
	for z in main.zombies: z.set_physics_process(false)
	var town: Node = main.town.get_node("StressTown")
	# Flattened looks.
	var bookcase = town.find_children("*", "", true, false).filter(func(n): return n is KitBox and str(n.name).ends_with("Bookcase"))
	check(not bookcase.is_empty(), "a bookcase to look at")
	if not bookcase.is_empty():
		var prop: KitProp = bookcase[0].find_children("*", "Node3D", true, false).filter(func(n): return n is KitProp)[0]
		var box := KitProp._bounds(prop.look, Transform3D.IDENTITY)
		check(prop.meshes().size() <= 3 and (box.size * prop.look.scale).distance_to(bookcase[0].size) < 0.05,
				"a bookcase's 40-odd boxes are one mesh, the same size (%d meshes)" % prop.meshes().size())
	# Batches.
	var batches := main.find_children("*", "MultiMeshInstance3D", true, false)
	var copies := 0
	for b: MultiMeshInstance3D in batches: copies += b.multimesh.instance_count
	check(batches.size() > 10 and copies > batches.size() * 2, "repeated looks drawn in batches (%d batches, %d copies)" % [batches.size(), copies])
	var spot = main.loot_spots.filter(func(s): return batched(s))
	check(not spot.is_empty(), "containers are batched")
	if not spot.is_empty():
		var c = spot[0]
		check(not shown(c), "...their own meshes hidden meanwhile")
		c.open()
		check(not batched(c) and shown(c), "searched (darkened): out of its batch, drawn on its own")
	var door = main.doors.filter(func(d): return batched(d) and not d.in_navigation)
	check(not door.is_empty(), "doors are batched")
	if not door.is_empty():
		door[0].set_open(true, false)
		check(not batched(door[0]) and shown(door[0]), "a door that opens leaves its batch")
	var pane = main.windows.filter(func(w): return batched(w))
	check(not pane.is_empty(), "windows are batched")
	if not pane.is_empty():
		pane[0].smash(true)
		check(not batched(pane[0]), "a smashed window leaves its batch")
	# Merged meshes keep the flattened stand-ins' colors.
	var colored := false
	for m: MeshInstance3D in main.town.get_node("MergedMeshes").get_children():
		for s in m.mesh.get_surface_count():
			var colors = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			if colors != null and (colors as PackedColorArray).size() > 0 and Array(colors).any(func(c): return not c.is_equal_approx(Color.WHITE)):
				colored = true
	check(colored, "merged meshes keep the stand-ins' colors")
	# Occluders.
	var buildings := town.get_children().filter(func(n): return n is KitBuilding)
	var with := buildings.filter(func(b): return b.get_children(true).any(func(n): return n is OccluderInstance3D and n.occluder and n.occluder.vertices.size() > 0))
	check(with.size() == buildings.size(), "every building hides what's behind it (%d of %d have occluders)" % [with.size(), buildings.size()])
	check(root.use_occlusion_culling, "occlusion culling is on")
	Settings.set_value("occlusion_culling", false)
	check(not root.use_occlusion_culling, "...and the setting turns it off")
	Settings.set_value("occlusion_culling", true)
	print("FAILS: %d" % fails)
	return true
