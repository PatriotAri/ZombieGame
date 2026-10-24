extends SceneTree
## Mines phase 2 in the game: a ramp zombies path down; an open shaft (falls
## hurt by height); a ladder you climb and step off; a cage that needs a
## running generator (a gas can), carries you and a zombie, shuts its gates;
## the mine's state saved and loaded.
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
var main: Node
var f := 0
var fails := 0
var mine: KitMine
var p: Node
var phase := 0
var t0 := 0
var z: Node
var cage: MineCage

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
	var t1 := MineTunnel.make(pts([Vector3i(0, 0, 0), Vector3i(0, 0, -8), Vector3i(0, -1, -12), Vector3i(5, -1, -12)]))
	t1.entrance_at_start = true
	mine.tunnels = [t1,
		MineTunnel.make(pts([Vector3i(7, -2, -12), Vector3i(10, -2, -12)])), # past the ladder, below
		MineTunnel.make(pts([Vector3i(0, 0, -4), Vector3i(4, 0, -4)])), # to the cage
		MineTunnel.make(pts([Vector3i(5, -2, -5), Vector3i(5, -2, -9)])), # the cage's bottom
		MineTunnel.make(pts([Vector3i(0, 0, -6), Vector3i(-2, 0, -6)]))] # to the open shaft
	mine.shafts = [MineShaft.make(Vector2i(6, -12), -1, -2), MineShaft.make(Vector2i(5, -4), 0, -2, MineShaft.Kind.CAGE),
		MineShaft.make(Vector2i(-3, -6), 0, -2, MineShaft.Kind.OPEN)]
	var gen := MineGenerator.new()
	gen.name = "Generator"
	gen.position = KitMine.cell_position(Vector3i(3, 0, -4)) + Vector3(0, 0, 0.6)
	mine.add_child(gen)
	mine.position = Vector3(0, 0, -40)
	map_root.add_child(mine)
	mine.owner = map_root
	gen.owner = map_root
	var packed := PackedScene.new()
	packed.pack(map_root)
	map_root.free()
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = packed
	root.add_child(main)

func g(cell: Vector3i, up := 0.05) -> Vector3:
	return mine.to_global(KitMine.cell_position(cell)) + Vector3(0, up, 0)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = main.player
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
		var cages := main.find_children("*", "MineCage", true, false)
		print("    in group: ", cages[0].is_in_group(&"not_in_navigation"), " gates: ", main.get_tree().get_nodes_in_group(&"not_in_navigation").map(func(n: Node) -> String: return str(n.get_path())))
		print("    cages: ", cages.size(), " ", cages.map(func(c: Node) -> String: return str(c.get_path())))
		cage = cages[0] if cages.size() > 0 else null
		check(cage != null and not main.nav_region.is_ancestor_of(cage), "the cage is kept out of the navigation bake")
		phase = 1
	if phase == 1 and f > 60 and main.nav_region._dirty.is_empty() and main.nav_region._baking.is_empty():
		var nav_map: RID = main.get_world_3d().navigation_map
		var to := g(Vector3i(4, -1, -12), 0.1)
		var path := NavigationServer3D.map_get_path(nav_map, NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 0, -25)), to, true)
		check(path.size() > 1 and path[-1].distance_to(to) < 1.0, "zombies path down the ramp to level -1 (ends %.1f m off)" % (path[-1].distance_to(to) if path.size() else 99.0))
		# A short drop: nothing. The open shaft, 8 m: half your health.
		p.health = 100.0
		p.global_position = g(Vector3i(0, 0, -2), 2.3)
		p.velocity = Vector3.ZERO
		phase = 2
		t0 = f
	if phase == 2 and f == t0 + 60:
		check(is_equal_approx(p.health, 100.0), "a 2.3 m drop doesn't hurt (%.0f)" % p.health)
		p.global_position = g(Vector3i(-3, 0, -6), 0.1)
		p.velocity = Vector3.ZERO
	if phase == 2 and f == t0 + 180:
		check(absf(p.global_position.y - g(Vector3i(-3, -2, -6), 0.0).y) < 0.2, "fell to the bottom of the open shaft")
		check(absf(p.health - 50.0) < 3.0, "8 m down: half your health gone (%.0f)" % p.health)
		# The ladder: from the bottom (level -2), facing it (+Z), climb.
		p.health = 100.0
		p.global_position = g(Vector3i(6, -2, -12), 0.05) + Vector3(0, 0, 0.6)
		p.velocity = Vector3.ZERO
		p.rotation.y = PI
		p.camera.rotation.x = 0.0
		Input.action_press("move_forward")
		phase = 3
		t0 = f
	if phase == 3 and f == t0 + 300:
		Input.action_release("move_forward")
		check(p.global_position.y > g(Vector3i(6, -1, -12), 0.0).y - 0.3, "climbed the ladder to level -1 (%.2f)" % (p.global_position.y - mine.global_position.y))
		Input.action_press("move_back") # off onto the landing (-Z half)
	if phase == 3 and f == t0 + 360:
		Input.action_release("move_back")
	if phase == 3 and f == t0 + 420:
		var on: float = p.global_position.y - g(Vector3i(6, -1, -12), 0.0).y
		check(p.is_on_floor() and absf(on) < 0.15, "stepped off onto the landing (%.2f over the floor)" % on)
		check(is_equal_approx(p.health, 100.0), "no harm done climbing (%.0f)" % p.health)
		# The cage: at the top (level 0). No power: it won't go.
		check(is_equal_approx(cage.global_position.y, mine.global_position.y), "the cage starts at the top stop")
		var lever: MineControl = cage.get_node("Lever")
		p.global_position = g(Vector3i(5, 0, -4), 0.2)
		p.velocity = Vector3.ZERO
		check(lever.interact_prompt().contains("no power"), "no power: \"%s\"" % lever.interact_prompt())
		lever.interact(p)
		check(not cage._moving, "without power the lever does nothing")
		var gen: MineGenerator = mine.get_node("Generator")
		gen.interact(p)
		check(not gen.running(), "an empty-handed player can't start the generator")
		p.give_item("gas_can")
		gen.interact(p)
		check(gen.running() and is_equal_approx(gen.fuel, 1.0) and p.inventory.count("gas_can") == 0, "a gas can runs it for an hour")
		z = main._add_zombie(g(Vector3i(5, 0, -4), 0.2) + Vector3(-0.5, 0, 0.5))
		z.set_physics_process(true)
		z.global_position = g(Vector3i(5, 0, -4), 0.2) + Vector3(-0.5, 0, 0.5)
		z.damage_per_second = 0.0 # (here to ride along, not to bite)
		phase = 35
		t0 = f
	if phase == 35 and f == t0 + 120: # (settled and standing still by now)
		print("    zombie settled: floor %s velocity %s" % [z.is_on_floor(), z.velocity])
		var lever: MineControl = cage.get_node("Lever")
		lever.interact(p)
		check(cage._moving, "powered, the lever sends it down")
		phase = 4
		t0 = f
	if phase == 4 and f % 30 == 0 and is_instance_valid(z):
		print("    t+%d cage %.2f zombie %.2f floor %s player %.2f" % [f - t0, cage.global_position.y, z.global_position.y, z.is_on_floor(), p.global_position.y])
	if phase == 4 and f == t0 + 79 and is_instance_valid(z):
		for i in z.get_slide_collision_count():
			var col: KinematicCollision3D = z.get_slide_collision(i)
			print("    zombie touches ", col.get_collider(), " ", (col.get_collider() as Node).get_path() if col.get_collider() is Node else "", " at ", col.get_position())
		var q := PhysicsRayQueryParameters3D.create(z.global_position + Vector3.UP, z.global_position + Vector3.DOWN * 2.0, 0xFFFFFFFF, [z.get_rid()])
		var hit: Dictionary = z.get_world_3d().direct_space_state.intersect_ray(q)
		print("    under zombie: ", hit.get("collider"), " ", (hit["collider"] as Node).get_path() if hit.has("collider") else "", " ", hit.get("position"))
		print("    zombie xz off cage: ", z.global_position - cage.global_position)
	if phase == 4 and f == t0 + 30:
		var gate: StaticBody3D = cage.gates[1][0]
		check(gate.collision_layer != 0, "the top stop's gate shuts behind it")
	if phase == 4 and not cage._moving and f > t0 + 30:
		var bottom_y: float = g(Vector3i(5, -2, -4), 0.0).y
		check(absf(p.global_position.y - bottom_y) < 0.3, "you rode it down to the bottom (%.2f)" % (p.global_position.y - bottom_y))
		if is_instance_valid(z):
			print("    zombie at %.2f (bottom %.2f) dead %s health %.0f state %s" % [z.global_position.y, bottom_y, z.is_dead, z.health, z.state])
		check(is_instance_valid(z) and not z.is_dead and absf(z.global_position.y - bottom_y) < 0.6, "and the zombie in it with you")
		check(is_equal_approx(p.health, 100.0), "no fall damage riding it (%.0f)" % p.health)
		check(cage.gates[0].all(func(gt: StaticBody3D) -> bool: return gt.collision_layer == 0), "the bottom stop's gate is open")
		var saved := mine.save_state()
		mine.get_node("Generator").fuel = 0.0
		cage.load_state({"at": 1})
		mine.load_state(saved)
		check(cage.at == 0 and mine.get_node("Generator").fuel > 0.9, "the mine's generator and cage are saved and loaded")
		# A zombie down the tunnel follows you into the cage (its gate's open).
		z.global_position = g(Vector3i(5, -2, -8), 0.1)
		z.velocity = Vector3.ZERO
		z.target = p
		z.state = 2 # hunting (State.HUNT)
		phase = 5
		t0 = f
	if phase == 5 and f == t0 + 600:
		var off: Vector3 = z.global_position - p.global_position
		check(Vector2(off.x, off.z).length() < 1.6 and absf(off.y) < 0.6, "a zombie in the tunnel follows you into the cage (%.1f m off)" % Vector2(off.x, off.z).length())
		print("FAILS: %d" % fails)
		quit()
		return true
	if f > 5000:
		print("  FAIL timed out in phase %d" % phase)
		print("FAILS: %d" % (fails + 1))
		quit()
		return true
	return false
