extends SceneTree
## A zombie that hears something behind a shut door breaks it down; one that's
## only wandering past doesn't. On a test map with one shop (tests/support/test_map.gd).
const TestMap := preload("res://tests/support/test_map.gd")
var main: Node
var f := 0
var fails := 0
var shop: Node3D
var door: Node
var z: Node
var wanderer: Node
var door2: Node
var broke_at := -1

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	var map := TestMap.begin()
	TestMap.building(map, "Shop", Vector3(40, 0, 40))
	TestMap.building(map, "Shop2", Vector3(40, 0, 80))
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = TestMap.finish(map)
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	f += 1
	main.player.health = main.player.max_health
	if f == 80:
		main.player.global_position = Vector3(-170, 0.2, -80)
		main.player.set_physics_process(false)
		for q in main.zombies:
			q.set_physics_process(false); q.global_position = Vector3(500, 0, 500)
		shop = main.town.get_node("Buildings/Shop")
		door = main.doors.filter(func(d: Node) -> bool: return String(d.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/Shop")))[0]
		door.set_open(false, false)
		var outside: Vector3 = shop.global_transform * Vector3(-2.5, 0.1, TestMap.front_door_z(shop))
		z = main._add_zombie(outside, null, "walker")
		# One at the other shop's shut door with nothing to go in for: it wanders off.
		var shop2: Node3D = main.town.get_node("Buildings/Shop2")
		door2 = main.doors.filter(func(d: Node) -> bool: return String(d.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/Shop2")))[0]
		door2.set_open(false, false)
		wanderer = main._add_zombie(shop2.global_transform * Vector3(-1.5, 0.1, TestMap.front_door_z(shop2)), null, "walker")
	if f == 120:
		z.hear_noise(shop.global_transform * Vector3(6.0, 0.1, -2.0), 50.0)
	if f > 120 and broke_at < 0 and door.is_broken:
		broke_at = f
		z.set_meta("broke_state", z.state)
	if f == 120 + 60 * 25:
		check(broke_at > 0 and z.get_meta("broke_state", -1) == 1,
				"investigating: broke the door down after %.1f s (state then %d)" % [(broke_at - 120) / 60.0, z.get_meta("broke_state", -1)])
		check(not door2.is_broken and door2.health == door2.max_health,
				"wandering: left the other shop's door alone (health %.0f, state %d)" % [door2.health, wanderer.state])
		print("FAILS: %d" % fails)
		return true
	return false
