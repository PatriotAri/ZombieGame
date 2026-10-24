extends SceneTree
## Hordes: schedule, sizes, where they start, walking across, saving; and
## the population rule (nobody new turns up while a horde has the count over
## the population). The map has a store put in for it (a building with a door).
const SaveGame := preload("res://core/save_game.gd")
const Horde := preload("res://world/horde.gd")
const KitBuilding := preload("res://world/building.gd")

var main: Node
var f := 0
var fails := 0
var before := 0
var dead_before := 0
var horde_zombies: Array = []
var start_dist := {}
var side := Vector3.ZERO
var saved := {}
var map_scene: PackedScene # the map, with the store
var before_ids := {} # instance id -> true: the zombies up before the horde
var cap_ids := {} # ... and when the population check starts
var cap_count := 0


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	var store: Node3D = KitBuilding.new()
	store.name = "TestStore"
	store.template = "Corner store"
	store.template_variant = 0
	store.apply_template()
	store.position = Vector3(40, 0, 0) # (flat ground, near where you start)
	map_root.add_child(store)
	_own(store, map_root)
	map_scene = PackedScene.new()
	map_scene.pack(map_root)
	map_root.free()
	_start_main()


func _start_main() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = map_scene
	root.add_child(main)


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)


func _ids(nodes: Array) -> Dictionary:
	var ids := {}
	for n: Node in nodes:
		ids[n.get_instance_id()] = true
	return ids


var ready_at := -1
var loaded_at := -1
var loaded_count := 0

func _physics_process(_d: float) -> bool:
	f += 1
	# The game reloads the latest save a few seconds after you die (a second game
	# beside this one): keep the player alive, it's not what's being tested.
	if main.player.is_dead:
		print("  FAIL the player died")
		fails += 1
	main.player.health = main.player.max_health
	if ready_at < 0 and f > 82 and main.horde._outdoor_ready:
		ready_at = f
	if loaded_at > 0 and f == loaded_at + 2:
		loaded_count = main.get_tree().get_nodes_in_group("zombies").size()
		if loaded_count != saved["count"]:
			var by_parent := {}
			for z in main.get_tree().get_nodes_in_group("zombies"):
				var k := "%s#%d listed=%s" % [z.get_parent().name, z.get_parent().get_instance_id(), z in main.zombies]
				by_parent[k] = by_parent.get(k, 0) + 1
			print("DEBUG main #%d, root children %s, by parent %s" % [main.get_instance_id(), root.get_children().map(func(n: Node) -> String: return "%s#%d" % [n.name, n.get_instance_id()]), by_parent])
	if loaded_at > 0 and f > loaded_at + 5 and main.horde._outdoor_ready:
		_check_loaded()
		print("FAILS: %d" % fails)
		return true
	if f > 100000:
		print("TIMED OUT  FAILS: %d" % (fails + 1))
		return true
	var g := f - ready_at if ready_at > 0 else -1
	if f <= 82:
		_early()
	return _after(g)


func _early() -> void:
	match f:
		5:
			var h: Horde = main.horde
			check(h.next_day >= 11 and h.next_day <= 19 and h.last_size == 0, "first horde on day %d at %.1f h" % [h.next_day, h.next_hour])
			_check_sizes()
		80:
			before = main.get_tree().get_nodes_in_group("zombies").size()
			before_ids = _ids(main.get_tree().get_nodes_in_group("zombies"))
			dead_before = main.zombies.filter(func(z: Node) -> bool: return z.is_dead).size()
			main.day_night.day = main.horde.next_day
			main.day_night.hour = main.horde.next_hour + 0.01
			main.horde._check_timer = 0.0
		82:
			check(main.horde._sending == 20 and main.horde._baking, "horde on its way (20): outdoor map baking")


func _after(g: int) -> bool:
	match g:
		1:
			check(main.horde.last_size == 20 and main.horde._outdoor_ready, "horde sent (20) after the bake")
			var store: Node3D = main.town.get_node("TestStore")
			var lift := Vector3(0, store.floor_top(0) + 0.1, 0)
			var inside: Vector3 = store.outside_front_door(-2.5) + lift
			var outside: Vector3 = store.outside_front_door(4.0) + Vector3(0, 0.1, 0)
			var town_path := NavigationServer3D.map_get_path(main.get_world_3d().navigation_map, outside, inside, true)
			var out_path := NavigationServer3D.map_get_path(main.horde.outdoor_map, outside, inside, true)
			var town_gap := _flat_gap(town_path, inside)
			var out_gap := _flat_gap(out_path, inside)
			check(town_gap < 1.0 and out_gap > 2.0,
					"outdoor map: no way into the store past its door (town map: %.1f m short, outdoor map: %.1f m short)" % [town_gap, out_gap])
			check(main.horde.next_day >= main.day_night.day + 10 and main.horde.next_day <= main.day_night.day + 18, "next one on day %d" % main.horde.next_day)
		60:
			var now: Array = main.get_tree().get_nodes_in_group("zombies")
			var died: int = main.zombies.filter(func(z: Node) -> bool: return z.is_dead).size() - dead_before
			horde_zombies = now.filter(func(z: Node) -> bool: return z.march_to != Vector3.INF)
			var arrivals := now.filter(func(z: Node) -> bool: return not before_ids.has(z.get_instance_id()) and z.march_to == Vector3.INF)
			check(horde_zombies.size() == 20 and horde_zombies.all(func(z: Node) -> bool: return not before_ids.has(z.get_instance_id())),
					"20 marching, all of them new")
			check(now.size() + died == before + 20 + arrivals.size(),
					"zombies %d -> %d: the horde's 20, %d ordinary arrivals (%d up, under the population %d), %d died"
					% [before, now.size(), arrivals.size(), now.size(), main.zombie_population, died])
			var mid := Vector3.ZERO
			var nearest := INF
			for z: Node3D in horde_zombies:
				mid += z.global_position / horde_zombies.size()
				nearest = minf(nearest, z.global_position.distance_to(main.player.global_position))
			var spread := 0.0
			for z: Node3D in horde_zombies:
				spread = maxf(spread, Vector2(z.global_position.x - mid.x, z.global_position.z - mid.z).length())
			check(nearest >= 100.0, "nearest to you: %.0f m" % nearest)
			check(spread <= 30.0, "together: within %.1f m of the middle (%s)" % [spread, mid])
			var b: Rect2 = main.zombie_population_node.bounds
			var center := Vector3(b.get_center().x, 0, b.get_center().y)
			side = Vector3(mid.x - center.x, 0, mid.z - center.z).normalized()
			var across_ok := true
			for z: Node3D in horde_zombies:
				var trip: Vector3 = z.march_to - z.global_position
				start_dist[z] = Vector2(trip.x, trip.z).length()
				if trip.dot(side) > 0.0 or start_dist[z] < 100.0:
					across_ok = false
			check(across_ok, "each walks to the far side (min trip %.0f m)" % start_dist.values().min())
			# Saved partway: horde state and each one's walk come back.
			saved["count"] = now.size()
			saved["next_day"] = main.horde.next_day
			main._save_game(SaveGame.new_path())
			# The population rule: over it (a horde can push the count over), nobody new turns up...
			var pop: Node = main.zombie_population_node
			pop.population = pop._alive() - 5
			pop._spawn_timer = 0.0
			cap_ids = _ids(main.get_tree().get_nodes_in_group("zombies"))
			cap_count = pop._alive()
		240:
			var pop: Node = main.zombie_population_node
			var new := main.get_tree().get_nodes_in_group("zombies").filter(func(z: Node) -> bool: return not cap_ids.has(z.get_instance_id()))
			check(new.is_empty(), "over the population (%d up, population %d): nobody new in 3 s (%d)" % [cap_count, pop.population, new.size()])
			# ... and under it, one turns up as soon as one's due.
			pop.population = pop._alive() + 1
			pop._spawn_timer = 0.0
			cap_ids = _ids(main.get_tree().get_nodes_in_group("zombies"))
		420:
			var new := main.get_tree().get_nodes_in_group("zombies").filter(func(z: Node) -> bool: return not cap_ids.has(z.get_instance_id()))
			check(new.size() == 1, "one under the population: one arrives (%d)" % new.size())
		660: # ~10 s of play
			var closer := 0
			for z: Node3D in horde_zombies:
				if z.is_dead:
					continue
				var trip: Vector3 = z.march_to - z.global_position
				if Vector2(trip.x, trip.z).length() < start_dist[z] - 3.0:
					closer += 1
			check(closer >= 16, "walking across: %d of 20 closer" % closer)
			# Interrupted, then picks the walk back up.
			var z: Node = horde_zombies[0]
			z._investigate(z.global_position + Vector3(2, 0, 0))
			z._set_idle()
			z.wander_timer = 0.0
			# Arrives: an ordinary zombie again.
			var arriving: Node3D = horde_zombies[1]
			arriving.global_position = arriving.march_to + Vector3(0.5, 0.1, 0)
			arriving.wander_timer = 0.0
			arriving.state = 0
		680:
			var z: Node = horde_zombies[0]
			check(z.march_to != Vector3.INF and z.wander_target == z.march_to and z.roaming, "back on its walk after investigating")
		860:
			check(horde_zombies[1].march_to == Vector3.INF, "arrived: ordinary zombie (march %s)" % horde_zombies[1].march_to)
			SaveGame.pending_load = SaveGame.read(SaveGame.latest())
			root.remove_child(main)
			main.free()
			_start_main()
			loaded_at = f
	return false


func _check_sizes() -> void:
	var h := Horde.new()
	h._rng.seed = 7
	var sizes: Array[int] = []
	var ok := true
	for i in 30:
		var s := h._next_size()
		if i == 0 and s != 20:
			ok = false
		if i > 0 and not h.peaked and (s - h.last_size > 7 or (s - h.last_size < 3 and s != 40)):
			ok = false
		if h.peaked and (s < 25 or s > 40):
			ok = false
		h.last_size = s
		h.peaked = h.peaked or s >= 40
		sizes.append(s)
	check(ok and h.peaked, "sizes: %s" % [sizes])
	h.free()


func _check_loaded() -> void:
	var now: Array = main.get_tree().get_nodes_in_group("zombies")
	check(loaded_count == saved["count"], "loaded zombies %d (saved %d)" % [loaded_count, saved["count"]])
	var marchers := now.filter(func(z: Node) -> bool: return z.march_to != Vector3.INF)
	check(marchers.size() == 20 and marchers.all(func(z: Node) -> bool: return z.march_map == main.horde.outdoor_map and z.march_map.is_valid()), "20 still marching after load, on the outdoor map")
	check(main.horde.next_day == saved["next_day"] and main.horde.last_size == 20, "horde schedule restored")
	# A save from before hordes: first one 10-18 days after its day.
	var h: Horde = main.horde
	main.day_night.day = 40
	h.load_state({})
	check(h.next_day >= 50 and h.next_day <= 58, "old save: next on day %d" % h.next_day)


## How far short of the point `to` (along the ground) a path ends; INF with no path.
func _flat_gap(path: PackedVector3Array, to: Vector3) -> float:
	if path.is_empty():
		return INF
	var end := path[path.size() - 1]
	return Vector2(end.x - to.x, end.z - to.z).length()
