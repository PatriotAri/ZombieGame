extends SceneTree
const KitBuilding := preload("res://world/building.gd")
var main: Node
var f := 0
var house: Node3D
var body: CharacterBody3D
var baked_at := -1
var fails := 0
func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1
func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
		main.player.set_physics_process(false)
		house = KitBuilding.new()
		house.position = Vector3(-110, 0, -70)
		house.size_depth = 10.0
		house.size_width = 9.0
		house.floors = 3
		house.floor_y = 0.02
		house.default_openings()
		main.nav_region.add_child(house)
		print("warnings: ", house._get_configuration_warnings())
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		main.fortifications.rebake()
		# A body the size of a zombie, walking straight at the stairs.
		body = CharacterBody3D.new()
		var shape := CapsuleShape3D.new(); shape.radius = 0.35; shape.height = 1.75
		var col := CollisionShape3D.new(); col.shape = shape; col.position.y = 0.875
		body.add_child(col)
		root.add_child(body)
		body.global_position = Vector3(-109.1, 0.05, -73.5) # just before the first flight, on its line
	if f > 3 and f < 400:
		body.velocity = Vector3(2.0, body.velocity.y - 9.8 / 60.0, 0)
		body.move_and_slide()
	if f == 400:
		check(body.global_position.y > 3.4, "walked up the first flight: now at %s" % body.global_position)
	if baked_at > 0 and f == baked_at + 70:
		var map: RID = main.get_world_3d().navigation_map
		var from := Vector3(-102.0, 0.05, -68.0)
		for level in [1, 2]:
			var to := Vector3(-101.5, level * 3.6, -69.0) if level == 1 else Vector3(-101.5, 7.2, -72.0)
			var path := NavigationServer3D.map_get_path(map, from, to, true)
			var end: Vector3 = path[path.size() - 1] if path.size() else Vector3.INF
			check(end.distance_to(to) < 1.0, "path from the ground floor to floor %d (%d points, ends %s)" % [level + 1, path.size(), end])
	if f >= 400 and baked_at > 0 and f > baked_at + 70:
		print("FAILS: %d" % fails)
		return true
	return f > 1200
