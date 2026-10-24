extends SceneTree
## Building tools phase 1: a drawn L-shaped outline with two floors and a placed
## staircase: its walls follow the outline (numbered), floors cover only the
## inside, the stair hole is open, the navigation reaches upstairs, doors and
## windows land on numbered walls, corners given the other way round get turned,
## and an upper block and foundation follow the shape.
const KitBuilding := preload("res://world/building.gd")
var main: Node
var f := 0
var house: Node3D
var block: Node3D
var body: CharacterBody3D
var baked_at := -1
var fails := 0
var base := Vector3(-110, 0, -70)

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func down(local_x: float, local_z: float, from_y: float) -> Dictionary:
	var at: Vector3 = house.global_transform * Vector3(local_x, from_y, local_z)
	var q := PhysicsRayQueryParameters3D.create(at, at - Vector3(0, 6, 0))
	return root.get_world_3d().direct_space_state.intersect_ray(q)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
		main.player.set_physics_process(false)
		house = KitBuilding.new()
		house.position = base
		house.floors = 2
		house.floor_y = 0.02
		# An L: 12 deep on the -z side, 6 deep on the +z side. Given going the
		# "wrong" way round, to check it's turned.
		var l := PackedVector2Array([Vector2(0, 5), Vector2(0, -5), Vector2(12, -5), Vector2(12, 0), Vector2(6, 0), Vector2(6, 5)])
		house.footprint = l
		house.default_openings()
		var flights: Array[KitStair] = [KitStair.make(0, Vector2(2.0, -3.4), 0.0)]
		house.stairs = flights
		main.nav_region.add_child(house)
		print("warnings: ", house._get_configuration_warnings())
		block = KitBuilding.new()
		block.position = base + Vector3(0, 0, 30)
		block.footprint = PackedVector2Array([Vector2(0, -4), Vector2(0, 4), Vector2(5, 4), Vector2(5, 8), Vector2(10, 8), Vector2(10, -4)])
		block.upper_height = 6.0
		block.default_openings()
		main.nav_region.add_child(block)
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		main.fortifications.rebake()
	if f == 5:
		check(house.edge_count() == 6, "six walls round the L")
		var area := 0.0
		var poly: PackedVector2Array = house.outline()
		for i in poly.size():
			area += poly[i].x * poly[(i + 1) % poly.size()].y - poly[(i + 1) % poly.size()].x * poly[i].y
		check(area < 0.0 and poly[0] == Vector2(0, -5) and poly[1] == Vector2(0, 5), "corners given the other way round are turned (wall 0 is the front)")
		check(house.contains_local(Vector2(9, -2)) and not house.contains_local(Vector2(9, 3)), "inside the L, and not in its notch")
		check(house._get_configuration_warnings().is_empty(), "no warnings (%s)" % [house._get_configuration_warnings()])
		var names: Array = house.get_children(true).map(func(n): return n.name)
		check("Wall0Door" in names, "the front door is Wall0Door (%s)" % [names.filter(func(n): return "Wall" in n)])
		var windows: Array = names.filter(func(n): return "Window" in n)
		check(windows.size() >= 4, "windows in the walls long enough (%d)" % windows.size())
		var up := down(9, -2, 5.0)
		check(not up.is_empty() and absf(up["position"].y - (base.y + 3.6)) < 0.05, "the upstairs floor inside the L (%.2f)" % (up["position"].y if not up.is_empty() else -1.0))
		var notch := down(9, 3, 5.0)
		check(notch.is_empty() or notch["position"].y < base.y + 1.0, "nothing up there over the notch")
		var hole := down(5.0, -3.4, 5.0)
		check(not hole.is_empty() and hole["position"].y < base.y + 3.3 and hole["position"].y > base.y + 0.5, "the stairs come up through the hole (ramp at %.2f)" % (hole["position"].y if not hole.is_empty() else -1.0))
		var ground := down(9, -2, 2.0)
		check(not ground.is_empty() and absf(ground["position"].y - (base.y + 0.02)) < 0.05, "the ground floor")
		var top := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
				block.global_transform * Vector3(7.5, 20, 6), block.global_transform * Vector3(7.5, 0, 6)))
		check(not top.is_empty() and absf(top["position"].y - (block.global_position.y + 3.6 + 6.0)) < 0.05, "an upper block over the drawn shape, with its roof")
		check(block.ground_corners().size() == 6, "the map screen gets its six corners")
		check(house.outside_front_door(3.0).distance_to(base + Vector3(-3.0, 0, 0)) < 0.3, "out front of the door (%s)" % (house.outside_front_door(3.0) - base))
		# A body walks up the stairs.
		body = CharacterBody3D.new()
		var shape := CapsuleShape3D.new(); shape.radius = 0.35; shape.height = 1.75
		var col := CollisionShape3D.new(); col.shape = shape; col.position.y = 0.875
		body.add_child(col)
		root.add_child(body)
		body.global_position = house.global_transform * Vector3(1.2, 0.1, -3.4)
	if f > 5 and f < 400:
		body.velocity = house.global_basis.x * 2.0 + Vector3(0, body.velocity.y - 9.8 / 60.0, 0)
		body.move_and_slide()
	if f == 400:
		check(body.global_position.y > base.y + 3.4, "walked up the stairs: now %.2f m up" % (body.global_position.y - base.y))
	if baked_at > 0 and f == baked_at + 70:
		var map: RID = main.get_world_3d().navigation_map
		# From inside (a building added during play keeps its door in the bake;
		# main.gd moves a map's doors out first).
		var from: Vector3 = house.global_transform * Vector3(3.0, 0.05, 2.5)
		var to: Vector3 = house.global_transform * Vector3(10.5, 3.6, -1.5)
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var end: Vector3 = path[path.size() - 1] if path.size() else Vector3.INF
		check(end.distance_to(to) < 1.0, "a path from the ground floor in the short wing up to the far end upstairs (%d points)" % path.size())
		print("    path: ", Array(path).map(func(p): return house.to_local(p).snappedf(0.1)))
		for t: Vector3 in [Vector3(9, 3.6, -3.4), Vector3(3, 3.6, -1), Vector3(10.5, 3.6, -1.5), Vector3(9, 1.0, -3.4)]:
			var c := NavigationServer3D.map_get_closest_point(map, house.global_transform * t)
			print("    closest to %s: %s" % [t, house.to_local(c).snappedf(0.1)])
	if f >= 400 and baked_at > 0 and f > baked_at + 70:
		print("FAILS: %d" % fails)
		return true
	return f > 1500
