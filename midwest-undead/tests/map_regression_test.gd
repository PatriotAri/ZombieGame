extends SceneTree
## The old town tests' mechanics on the new map: a test map made in memory from
## world/map/map.tscn plus a shop (door, windows, a counter), a two-storey house
## (stairs), a trader, a Place and a ZombieSpawn. Checks: everything's found,
## boarding a window (tile rebake), a zombie breaking a door to a noise, a path
## upstairs, and a save and load bringing it all back.
const SaveGame := preload("res://core/save_game.gd")
const TestMap := preload("res://tests/support/test_map.gd")
var main: Node
var test_map: PackedScene
var f := 0
var fails := 0
var shop: Node3D
var house: Node3D
var window_index := -1
var z: Node
var door: Node
var t_broke := -1
var saved := {}

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	shop = KitBuilding.new(); shop.name = "Shop"
	shop.size_depth = 10.0; shop.size_width = 8.0; shop.floor_y = 0.02
	shop.default_openings()
	shop.position = Vector3(40, 0, 40)
	map_root.get_node("Buildings").add_child(shop); shop.owner = map_root
	var counter: Node3D = load("res://world/kit/furniture/counter.tscn").instantiate()
	counter.name = "Counter"
	shop.add_child(counter); counter.owner = map_root
	counter.position = Vector3(6, 0.02, 2)
	house = KitBuilding.new(); house.name = "House"
	house.floors = 2; house.size_depth = 12.0; house.size_width = 9.0; house.floor_y = 0.02
	house.default_openings()
	house.position = Vector3(80, 0, 40)
	map_root.get_node("Buildings").add_child(house); house.owner = map_root
	var markers := map_root.get_node("Markers")
	for spec: Array in [["Trader", "trader", Vector3(0, 0.1, 12)], ["Chief", "chief", Vector3(3, 0.1, 12)]]:
		var sp := KitSpawnPoint.new(); sp.name = spec[0]; sp.role = spec[1]; sp.position = spec[2]
		markers.add_child(sp); sp.owner = map_root
	var place := KitPlace.new(); place.name = "Station"; place.place_name = "Police Station"
	markers.add_child(place); place.owner = map_root
	var zs := KitZombieSpawn.new(); zs.name = "Spawn"; zs.count = 5; zs.spread = Vector2(10, 10)
	zs.position = Vector3(-150, 0, -150)
	markers.add_child(zs); zs.owner = map_root
	test_map = PackedScene.new()
	test_map.pack(map_root)
	map_root.free()
	_start()

func _start() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	main.extra_zombies = 0 # only the ZombieSpawn's (one scattered nearby would throw its count off)
	root.add_child(main)


func _find() -> void:
	shop = main.town.get_node("Buildings/Shop")
	house = main.town.get_node("Buildings/House")

func _physics_process(_d: float) -> bool:
	f += 1
	main.player.health = main.player.max_health
	if false:
		var states := []
		for tile in main.nav_region._baking: states.append(NavigationServer3D.is_baking_navigation_mesh(main.nav_region._baking[tile]))
		print("    f %d baking %s" % [f, states])
	match f:
		60:
			_find()
			check(main.doors.size() >= 2 and main.windows.size() >= 4, "found %d doors and %d windows" % [main.doors.size(), main.windows.size()])
			check(main.trader != null and main.chief != null, "trader and chief at their markers")
			check(main.places.size() == 1, "the Place is found")
			var near_spawn: Array = main.zombies.filter(func(q: Node) -> bool: return q.global_position.distance_to(Vector3(-150, 0, -150)) < 20.0)
			check(near_spawn.size() == 5, "ZombieSpawn: %d zombies around it" % near_spawn.size())
			for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
			main.player.global_position = Vector3(0, 0.2, -30)
			# Board up one of the shop's windows (not quietly: the tile around it re-bakes).
			for i in main.fortifications.openings.size():
				var o: Dictionary = main.fortifications.openings[i]
				if o["kind"] == "window" and String(o["id"]).begins_with(TestMap.under(main, "Buildings/Shop")):
					window_index = i
					break
			main.fortifications.board(window_index)
			check(not main.nav_region._baking.is_empty(), "boarding a window re-bakes the tiles around it (%d)" % main.nav_region._baking.size())
		200:
			var o: Dictionary = main.fortifications.openings[window_index]
			check(o["planks"] != null and not (o["link"] as NavigationLink3D).enabled, "window planked; zombies can't climb in there")
			# A zombie outside the shut front door hears something inside: it breaks the door down.
			door = main.doors.filter(func(d: Node) -> bool: return String(d.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/Shop")))[0]
			door.set_open(false, false)
			z = main._add_zombie(shop.global_transform * Vector3(-2.5, 0.1, front_door_z(shop)), null, "walker")
		230:
			z.hear_noise(shop.global_transform * Vector3(6.0, 0.1, -2.0), 50.0)
	if f > 230 and t_broke < 0 and door and door.is_broken:
		t_broke = f
	match f:
		230 + 60 * 30:
			check(main.nav_region._baking.is_empty(), "...and the re-bake finished")
			check(t_broke > 0, "investigating zombie broke the shop door down (after %.1f s)" % ((t_broke - 230) / 60.0))
			var m: RID = main.get_world_3d().navigation_map
			var upstairs: Vector3 = house.global_transform * Vector3(9.0, house.floor_top(1) + 0.1, -2.0)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(m, Vector3(75, 0.1, 40), upstairs, true, 3)
			check(not path.is_empty() and path[path.size() - 1].distance_to(upstairs) < 1.0, "a path from outside up the stairs to the house's upper floor (ends %.1f m off)" % (path[path.size() - 1].distance_to(upstairs) if path.size() else INF))
			main.trader.stock.add("pistol_ammo", 7)
			saved["boarded"] = main.fortifications.save_state()["boarded"]
			saved["ammo"] = main.trader.stock.count("pistol_ammo")
			main._save_game(SaveGame.new_path())
			SaveGame.pending_load = SaveGame.read(SaveGame.latest())
			root.remove_child(main); main.free()
			_start()
		230 + 60 * 30 + 5:
			_find()
		230 + 60 * 30 + 60:
			check(main.fortifications.save_state()["boarded"] == saved["boarded"], "loaded: the planked window is still planked")
			var d: Node = main.doors.filter(func(q: Node) -> bool: return String(q.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/Shop")))[0]
			check(d.is_broken, "loaded: the broken door is still broken")
			check(main.trader.stock.count("pistol_ammo") == saved["ammo"], "loaded: the trader's stock")
			print("FAILS: %d" % fails)
			return true
	return false


## Local z of the middle of a building's ground-floor front door (0 if none).
func front_door_z(b: Node) -> float:
	for op in b.openings:
		if op and op.kind == "door" and b.edge_of(op) == 0 and op.level == 0:
			return op.offset
	return 0.0
