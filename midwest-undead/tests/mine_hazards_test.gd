extends SceneTree
## Mines phase 3 in the game: a cave-in blocks a tunnel (and zombies' paths)
## until you dig through it with a pickaxe (the digging is kept when you
## stop); a tunnel flooded to its roof: your breath runs out, then you drown
## (health), and comes back in the air; a zombie in it drowns; the dug-out
## cave-in is saved.
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
var main: Node
var f := 0
var fails := 0
var mine: KitMine
var p: Node
var phase := 0
var t0 := 0
var z: Node
var heap: MineCaveIn
var rebaked_at := -1

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func pts(a: Array) -> Array[Vector3i]:
	var r: Array[Vector3i] = []
	r.assign(a)
	return r

func _initialize() -> void:
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	mine = KitMine.new()
	mine.name = "TestMine"
	var t1 := MineTunnel.make(pts([Vector3i(0, 0, 0), Vector3i(0, 0, -10)]))
	t1.entrance_at_start = true
	mine.tunnels = [t1, MineTunnel.make(pts([Vector3i(0, 0, -3), Vector3i(6, 0, -3)]))]
	var caves: Array[Vector3i] = [Vector3i(0, 0, -6)]
	mine.cave_ins = caves
	mine.floods = [MineFlood.make(Vector3i(3, 0, -3), Vector3i(6, 0, -3), 3.5), MineFlood.make(Vector3i(0, 0, -8), Vector3i(0, 0, -10), 2.0)]
	mine.position = Vector3(0, 0, -40)
	map_root.add_child(mine)
	mine.owner = map_root
	var packed := PackedScene.new()
	packed.pack(map_root)
	map_root.free()
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = packed
	root.add_child(main)

func g(cell: Vector3i, up := 0.05) -> Vector3:
	return mine.to_global(KitMine.cell_position(cell)) + Vector3(0, up, 0)

func path_end(to: Vector3) -> float:
	var nav_map: RID = main.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(nav_map, NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 0, -30)), to, true)
	return path[-1].distance_to(to) if path.size() else 99.0

func baked() -> bool:
	return main.nav_region._dirty.is_empty() and main.nav_region._baking.is_empty()

func press_interact(down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = down
	Input.parse_input_event(ev)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = main.player
		p.health = 1e6
		for zz in main.zombies: zz.set_physics_process(false); zz.global_position = Vector3(-900, 0, 900)
		mine = main.town.get_node("TestMine")
		var t: Node = main.terrain
		var rect := Rect2(-40, -110, 90, 75)
		for x in range(int(rect.position.x), int(rect.end.x) + 1):
			for zc in range(int(rect.position.y), int(rect.end.y) + 1):
				t.data.set_height(Vector3(x, 0, zc), clampf((-zc - 38.25) * 1.5, 0.0, 12.0))
		TerrainEdit.finish(t, rect)
		mine.apply(t)
		main.nav_region._terrain_faces.clear()
		main.nav_region.rebake_all()
		heap = mine.find_children("*", "MineCaveIn", true, false)[0]
		phase = 1
	if phase == 1 and f > 60 and baked():
		var beyond := g(Vector3i(0, 0, -8), 0.1)
		check(path_end(beyond) > 2.0, "the cave-in blocks zombies' paths (%.1f m short)" % path_end(beyond))
		check(heap.interact_prompt().contains("pickaxe"), "without a pickaxe it says one's needed")
		# Face it with the pickaxe and hold interact for 4 s, then let go.
		p.give_item("pickaxe")
		p.select("pickaxe")
		p.global_position = g(Vector3i(0, 0, -5), 0.05) + Vector3(0, 0, 0.3)
		p.velocity = Vector3.ZERO
		p.rotation.y = 0.0 # facing -Z, at it
		p.camera.rotation.x = 0.0
		phase = 2
		t0 = f
	if phase == 2 and f == t0 + 40:
		check(p.prompt_text.contains("dig through"), "holding the pickaxe: \"%s\"" % p.prompt_text)
		press_interact(true)
	if phase == 2 and f == t0 + 40 + 240:
		press_interact(false)
	if phase == 2 and f == t0 + 300:
		check(heap.dug() > 0.25 and heap.dug() < 0.4 and is_instance_valid(heap) and heap.is_inside_tree(), "4 s in, a third dug, and it keeps that when you stop (%.0f%%)" % (100.0 * heap.dug()))
		press_interact(true)
	if phase == 2 and f == t0 + 300 + 60 * 9:
		press_interact(false)
		check(not is_instance_valid(heap) or not heap.is_inside_tree(), "dug through after 12 s in all")
		var walk := g(Vector3i(0, 0, -6), 1.0)
		var q := PhysicsRayQueryParameters3D.create(walk + Vector3(0, 0, 2.0), walk + Vector3(0, 0, -2.0))
		check(main.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "the way through is open")
		main.nav_region.bake_finished.connect(func() -> void: rebaked_at = f, CONNECT_ONE_SHOT)
		var saved := mine.save_state()
		check((saved["dug"] as Array).size() == 1, "the mine remembers it's dug out (saved: %s)" % str(saved["dug"]))
		phase = 3
		t0 = f
	if phase == 3 and rebaked_at > 0 and f > rebaked_at + 10 and baked():
		check(path_end(g(Vector3i(0, 0, -8), 0.1)) < 1.0, "zombies' paths go through again")
		# The flooded tunnel: in to the roof.
		p.global_position = g(Vector3i(4, 0, -3), 0.5)
		p.velocity = Vector3.ZERO
		z = main._add_zombie(g(Vector3i(5, 0, -3), 0.2))
		z.set_physics_process(true)
		phase = 4
		t0 = f
	if phase == 4 and f == t0 + 30:
		check(p.swimming and p.head_under, "under water to the roof: swimming, head under")
		check(p.breath < p.BREATH, "holding your breath (%.1f s left)" % p.breath)
		p.breath = 0.5
		p.health = 100.0
	if phase == 4 and f == t0 + 30 + 120:
		check(p.health < 95.0 and p.health > 70.0, "out of breath: drowning (%.0f health after ~2 s)" % p.health)
		p.global_position = g(Vector3i(1, 0, -3), 0.1)
		p.velocity = Vector3.ZERO
	if phase == 4 and f == t0 + 30 + 120 + 300:
		check(not p.head_under and absf(p.breath - 15.0) < 0.5, "back in the air your breath comes back, three times as fast (%.1f s after 5 s)" % p.breath)
		check(not is_instance_valid(z) or z.is_dead, "the zombie in the flood drowned")
		# Deep but not to the roof: swim with your head up; crouch dives, jump comes back up.
		p.global_position = g(Vector3i(0, 0, -9), 0.6)
		p.velocity = Vector3.ZERO
		phase = 5
		t0 = f
	if phase == 5 and f == t0 + 60:
		check(p.swimming and not p.head_under, "2 m of water: swimming, head up")
		Input.action_press("crouch")
	if phase == 5 and f == t0 + 120:
		Input.action_release("crouch")
		check(p.head_under, "crouch: dived under")
		Input.action_press("jump")
	if phase == 5 and f == t0 + 180:
		Input.action_release("jump")
	if phase == 5 and f == t0 + 240:
		check(not p.head_under, "jump: back up for air")
		print("FAILS: %d" % fails)
		quit()
		return true
	if f > 8000:
		print("  FAIL timed out in phase %d" % phase)
		print("FAILS: %d" % (fails + 1))
		quit()
		return true
	return false
