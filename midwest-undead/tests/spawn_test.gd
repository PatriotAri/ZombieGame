extends SceneTree
## Queue B: zombies only turn up where you can't see them, 30 m+ from you, 40 m+
## from camps, anywhere on the map: the start-of-game extras, new ones during
## play, and marker zombies you'd have seen (moved out of sight nearby).
var main: Node
var test_map: PackedScene
var f := 0
var fails := 0
var pop: Node
var before := 0

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	var markers := map_root.get_node("Markers")
	var start := markers.get_node("PlayerStart") as Node3D
	# Six zombies right in front of where you start (in plain view), and a camp nearby.
	var zs := KitZombieSpawn.new(); zs.name = "InView"; zs.count = 6; zs.chance = 1.0
	zs.position = start.position + Vector3(0, 0, -15); zs.spread = Vector2(3, 3)
	markers.add_child(zs); zs.owner = map_root
	var camp := KitBaseCamp.new(); camp.name = "Station"; camp.position = start.position + Vector3(150, 0, 0)
	markers.add_child(camp); camp.owner = map_root
	test_map = PackedScene.new(); test_map.pack(map_root); map_root.free()
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	root.add_child(main)

func all_ok(points: Array) -> bool:
	for at: Vector3 in points:
		if at.distance_to(main.player.global_position) < 30.0 or pop.seen(at):
			return false
	return true

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 1:
		pop = main.zombie_population_node
		var at: Array = main.zombies.map(func(z) -> Vector3: return z.global_position - Vector3(0, 0.1, 0))
		var nearest := INF
		for p: Vector3 in at:
			nearest = minf(nearest, p.distance_to(main.player.global_position))
		check(main.zombies.size() >= 60, "the start: %d zombies (6 at the marker, the rest scattered)" % main.zombies.size())
		check(all_ok(at), "none of them where you can see them, the nearest %.0f m away" % nearest)
		var by_marker: Array = at.filter(func(p: Vector3) -> bool: return p.distance_to(main.player.global_position + Vector3(0, 0, -15)) < 60.0)
		check(by_marker.size() >= 6, "the marker's six moved out of sight but stayed near it (%d within 60 m)" % by_marker.size())
		main.player.set_physics_process(false)
		for z in main.zombies: z.set_physics_process(false)
	if f == 5:
		var cam: Camera3D = main.player.camera
		var ahead := cam.global_position - cam.global_basis.z * 40.0
		var behind := cam.global_position + cam.global_basis.z * 40.0
		check(pop.seen(Vector3(ahead.x, main.terrain.data.get_height(ahead), ahead.z)) and not pop.seen(Vector3(behind.x, main.terrain.data.get_height(behind), behind.z)),
				"in the open 40 m ahead is seen; 40 m behind you isn't")
		var spots := []
		for i in 200:
			var s: Vector3 = pop.hidden_spot(null)
			if s != Vector3.INF:
				spots.append(s)
		check(spots.size() >= 190 and all_ok(spots), "hidden spots: %d of 200 found, all unseen and 30 m+ away" % spots.size())
		var station: Vector3 = main.camps.station.center
		check(spots.all(func(s: Vector3) -> bool: return Vector2(s.x - station.x, s.z - station.z).length() >= 40.0), "none within 40 m of a camp")
		var far := spots.filter(func(s: Vector3) -> bool: return s.distance_to(main.player.global_position) > 300.0).size()
		var quads := {}
		for s: Vector3 in spots:
			quads[Vector2i(signi(int(s.x)), signi(int(s.z)))] = true
		check(far > 20 and quads.size() >= 4, "anywhere on the map: %d over 300 m away, in %d quarters" % [far, quads.size()])
		# During play: below the population, the next one turns up unseen.
		pop.population = main.zombies.size() + 5
		before = main.zombies.size()
		pop._spawn_timer = 0.0
		pop._check_timer = 0.0
	if f == 10:
		check(main.zombies.size() == before + 1, "a new one turns up during play")
		var newest: Vector3 = main.zombies[main.zombies.size() - 1].global_position - Vector3(0, 0.1, 0)
		check(all_ok([newest]), "...where you can't see it, %.0f m away" % newest.distance_to(main.player.global_position))
		print("FAILS: %d" % fails)
		return true
	return false
