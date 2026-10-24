extends SceneTree
## The optimizations behave: settings apply; damaged windows and doors darken
## on their own without changing the others; merged buildings still block;
## saves keep cracked glass. On a test map with
## two shops (tests/support/test_map.gd); the second has only a front door, so
## its back wall is solid.
const SaveGame := preload("res://core/save_game.gd")
const Settings := preload("res://core/settings.gd")
const TestMap := preload("res://tests/support/test_map.gd")
var main: Node
var test_map: PackedScene
var f := 0
var fails := 0
var cracked := ""
## Whether a window's or door's look has the darkening overlay (KitProp.darken).
func darkened(thing: Node) -> bool:
	return thing._look.meshes().any(func(m: MeshInstance3D) -> bool: return m.material_overlay != null)

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1
func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map := TestMap.begin()
	TestMap.building(map, "Shop", Vector3(40, 0, 40))
	var shell := TestMap.building(map, "Shell", Vector3(40, 0, 70))
	var only_door: Array[KitOpening] = [KitOpening.make("front", "door", 0.0, 1.6, 0.0, 2.4)]
	shell.openings = only_door
	test_map = TestMap.finish(map)
	_start()

func _start() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	root.add_child(main)
func _physics_process(_d: float) -> bool:
	f += 1
	main.player.health = main.player.max_health
	if f == 10:
		var sun: DirectionalLight3D = root.get_tree().get_nodes_in_group("sun")[0]
		check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and sun.directional_shadow_max_distance == 60.0, "default shadows: medium (2 layers, 60 m)")
		Settings.set_value("shadows", 0)
		check(not sun.shadow_enabled, "shadows off")
		Settings.set_value("shadows", 2)
		check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and sun.directional_shadow_max_distance == 100.0, "shadows high (4 layers, 100 m)")
		Settings.set_value("shadows", 1)
		var pane = main.windows[0]
		var glass: MeshInstance3D = pane._look.meshes()[0]
		check(is_equal_approx(glass.visibility_range_end, 70.0), "window drawn to 70 m (%.1f)" % glass.visibility_range_end)
		Settings.set_value("view_distance", 0.5)
		check(is_equal_approx(glass.visibility_range_end, 35.0), "view distance 50%%: 35 m (%.1f)" % glass.visibility_range_end)
		Settings.set_value("view_distance", 1.0)
		Settings.set_value("render_scale", 0.6)
		check(is_equal_approx(root.scaling_3d_scale, 0.6), "resolution 60%")
		Settings.set_value("render_scale", 1.0)
		# Windows: a cracked pane darkens on its own.
		var a = main.windows[0]; var b = main.windows[1]
		check(not darkened(a) and not darkened(b), "panes start clear")
		a.bash(10.0)
		check(darkened(a) and not darkened(b), "a cracked pane darkens, the other doesn't")
		cracked = a.get_meta("town_id")
		# Doors: one material per color, shared; a bashed one darkens on its own.
		var d1 = main.doors.filter(func(d: Node) -> bool: return d.breakable)[0]
		var d2 = main.doors.filter(func(d: Node) -> bool: return d.breakable and d != d1 and d.color == d1.color)[0]
		check(d1._material == d2._material, "two doors of a color share a material")
		d1.bash(30.0)
		check(darkened(d1) and not darkened(d2) and d1._material == d2._material, "a bashed door darkens on its own (an overlay: the shared material's untouched)")
		# Merged buildings still block.
		var merged: Node = main.town.get_node_or_null("MergedMeshes")
		check(merged != null and merged.get_child_count() > 0, "the buildings are merged into meshes: %d" % (merged.get_child_count() if merged else 0))
		var shell: Node3D = main.town.get_node("Buildings/Shell")
		var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		var hits := 0
		var back: float = shell.size_depth # (a building's front wall is at x = 0, its back at its depth)
		for z in [-3.0, -2.0, -1.0, 1.0, 2.0, 3.0]:
			for y in [0.6, 1.2, 1.8]:
				# From outside the back wall to inside the building.
				var from: Vector3 = shell.global_transform * Vector3(back + 2.0, y, z)
				var to: Vector3 = shell.global_transform * Vector3(back - 2.0, y, z)
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty(): hits += 1
		check(hits == 18, "a merged building's solid back wall still blocks rays: %d of 18" % hits)
		main.save_game(SaveGame.new_path())
	if f == 20:
		SaveGame.pending_load = SaveGame.read(SaveGame.latest())
		root.remove_child(main); main.free()
		_start()
	if f == 30:
		var pane = main.windows.filter(func(p: Node) -> bool: return p.get_meta("town_id") == cracked)[0]
		var other = main.windows.filter(func(p: Node) -> bool: return p.get_meta("town_id") != cracked)[0]
		check(darkened(pane) and not darkened(other), "the cracked pane loads cracked, on its own")
		print("FAILS: %d" % fails)
		return true
	return false
