extends SceneTree
## Mines phase 1 in the game: a mine in a hill (sculpted here), Applied:
## the hill opens at the mouth; zombies' navigation reaches the chamber; you
## stand on its floor; it's dark inside but for your flashlight. SHOTS=1 saves
## pictures (needs a window: run it without --headless), into TEST_OUT or the
## game's user folder.
var OUT := (OS.get_environment("TEST_OUT") if OS.get_environment("TEST_OUT") != "" else OS.get_user_data_dir()) + "/mine_"
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
const Ground := preload("res://world/ground.gd")
var main: Node
var f := 0
var fails := 0
var mine: KitMine
var baked := false
var shots := OS.get_environment("SHOTS") == "1"
var p: Node
var phase := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	mine = KitMine.new()
	mine.name = "TestMine"
	var a: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(0, 0, -12), Vector3i(8, 0, -12)]
	var t1 := MineTunnel.make(a, true)
	t1.carts = 2
	t1.entrance_at_start = true
	var d: Array[Vector3i] = [Vector3i(12, 0, -12), Vector3i(18, 0, -12)]
	var t2 := MineTunnel.make(d, true)
	t2.carts = 2
	mine.tunnels = [t1, t2]
	mine.chambers = [MineChamber.make(Vector3i(8, 0, -14), Vector3i(12, 0, -10), 6.0)]
	mine.position = Vector3(0, 0, -40)
	map_root.add_child(mine)
	mine.owner = map_root
	var packed := PackedScene.new()
	packed.pack(map_root)
	map_root.free()
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = packed
	root.add_child(main)

func hill(x: float, z: float) -> float:
	# Up from the end of the floor outside the mouth (z = -38.25, a vertex in from the floor's end), 12 m over the tunnel.
	return clampf((-z - 38.25) * 1.5, 0.0, 12.0)

func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = main.player
		p.health = 1e9
		for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
		mine = main.town.get_node("TestMine")
		var t: Node = main.terrain
		var rect := Rect2(-30, -110, 80, 75)
		for x in range(int(rect.position.x), int(rect.end.x) + 1):
			for z in range(int(rect.position.y), int(rect.end.y) + 1):
				t.data.set_height(Vector3(x, 0, z), hill(x, z))
		TerrainEdit.finish(t, rect)
		mine.apply(t)
		check(t.data.get_control_hole(Vector3(0, 0, -39)), "the hill is open at the mouth")
		check(not t.data.get_control_hole(Vector3(0, 0, -60)), "and closed over the tunnel deeper in")
		check(not t.data.get_control_hole(Vector3(10, 0, -39)), "and beside the mouth")
		main.nav_region._terrain_faces.clear()
		main.nav_region.rebake_all()
		check(Ground.height_range().x <= -0.4, "Ground reaches down to the mine (%.2f)" % Ground.height_range().x)
		var merged := 0
		for m in main.town.get_node("MergedMeshes").get_children():
			if (m as MeshInstance3D).layers == 2: merged += 1
		check(merged > 0, "merged mine meshes stay underground (%d)" % merged)
		var sunlit_rock: Array = main.town.get_node("MergedMeshes").get_children().filter(func(m: MeshInstance3D) -> bool:
			return m.layers == 1 and m.material_override == KitMine.ROCK)
		check(not sunlit_rock.is_empty(), "the portal's rock face is in the daylight")
		var sun_dir: Vector3 = main.get_tree().get_first_node_in_group("sun").global_basis.z
		print("    sun from ", sun_dir)
		var sun: DirectionalLight3D = main.get_tree().get_first_node_in_group("sun")
		check(sun.light_cull_mask & 2 == 0, "the sun leaves the mines out")
	if f > 60 and phase == 0 and main.nav_region._dirty.is_empty() and main.nav_region._baking.is_empty():
		phase = 1
		var nav_map: RID = main.get_world_3d().navigation_map
		var from := Vector3(0, 0, -25)
		var to := mine.to_global(KitMine.cell_position(Vector3i(10, 0, -12))) + Vector3(0, 0.1, 0)
		var path := NavigationServer3D.map_get_path(nav_map, NavigationServer3D.map_get_closest_point(nav_map, from), to, true)
		var end := path[-1] if path.size() > 0 else Vector3.INF
		print("    path ", path)
		for zz in [-35.0, -36.5, -38.0, -39.5, -41.0, -44.0, -50.0, -60.0]:
			print("    closest at z %.1f: %s  hole %s ground %.2f" % [zz, NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 0.3, zz)), main.terrain.data.get_control_hole(Vector3(0, 0, zz)), main.terrain.data.get_height(Vector3(0, 0, zz))])
		var deep := Array(path).any(func(q: Vector3) -> bool: return q.z < -45.0 and q.y < 1.0 and absf(q.x) < 2.0)
		check(path.size() > 1 and end.distance_to(to) < 1.0, "zombies can path into the chamber (ends %.1f m off)" % end.distance_to(to))
		check(deep, "the path goes through the tunnel (under the hill)")
		var over := NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 12, -60))
		check(over.y > 11.0, "and the hilltop over it is walkable too (%.1f)" % over.y)
		p.global_position = mine.to_global(KitMine.cell_position(Vector3i(0, 0, -6))) + Vector3(0.3, 0.5, 0)
		p.velocity = Vector3.ZERO
		p.rotation.y = 0.0
		p.camera.rotation.x = 0.0
		phase = 2
		f = 1000
	if phase == 2 and f == 1090:
		check(absf(p.global_position.y - 0.0) < 0.15, "you stand on the tunnel floor (%.2f)" % p.global_position.y)
		if not shots:
			print("FAILS: %d" % fails)
			quit()
			return true
		main.day_night.hour = 13.0; main.day_night.seconds_per_game_hour = 1e9
		p.set_physics_process(false)
		p.flashlight.visible = false
		p.global_position = Vector3(2, 0.05, -26); p.rotation.y = 0.05; p.camera.rotation.x = 0.05
	if shots and phase == 2:
		match f:
			1120: root.get_texture().get_image().save_png(OUT + "mouth.png")
			1121:
				p.global_position = mine.to_global(KitMine.cell_position(Vector3i(0, 0, -4))) + Vector3(0.3, 0.05, 0)
				p.rotation.y = 0.0
			1150: root.get_texture().get_image().save_png(OUT + "dark.png")
			1151: p.flashlight.visible = true
			1180: root.get_texture().get_image().save_png(OUT + "flashlight.png")
			1181:
				p.global_position = mine.to_global(KitMine.cell_position(Vector3i(3, 0, -12))) + Vector3(0, 0.05, 0)
				p.rotation.y = -PI / 2.0
			1210: root.get_texture().get_image().save_png(OUT + "chamber.png")
			1211:
				p.global_position = mine.to_global(KitMine.cell_position(Vector3i(0, 0, -11))) + Vector3(0, 0.05, 0)
				p.rotation.y = 0.0; p.camera.rotation.x = 0.0
				p.rotation.y = PI
			1240: root.get_texture().get_image().save_png(OUT + "out.png")
			1241:
				print("FAILS: %d" % fails)
				quit()
				return true
	return false
