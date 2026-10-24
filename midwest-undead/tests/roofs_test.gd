extends SceneTree
## Building tools phase 3: pitched roofs (gable, hip, shed, gambrel) over a
## rectangle and an L; a walk-in attic reached by stairs; standing on the roof;
## overhangs; dormers and chimneys; warnings for an angled outline and stairs
## to a closed attic.
const KitBuilding := preload("res://world/building.gd")
var main: Node
var f := 0
var house: Node3D
var ell: Node3D
var odd: Node3D
var closed: Node3D
var body: CharacterBody3D
var faller: CharacterBody3D
var baked_at := -1
var fails := 0
var base := Vector3(-110, 0, -70)

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func down(b: Node3D, x: float, z: float, from_y: float, to_y := -1.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(b.global_transform * Vector3(x, from_y, z), b.global_transform * Vector3(x, to_y, z))
	var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
	return b.to_local(hit["position"]).y if not hit.is_empty() else -99.0

func capsule() -> CharacterBody3D:
	var c := CharacterBody3D.new()
	var shape := CapsuleShape3D.new(); shape.radius = 0.35; shape.height = 1.75
	var col := CollisionShape3D.new(); col.shape = shape; col.position.y = 0.875
	c.add_child(col)
	c.floor_max_angle = deg_to_rad(46)
	root.add_child(c)
	return c

func make(at: Vector3, shape: String) -> Node3D:
	var b := KitBuilding.new()
	b.position = at
	b.floor_y = 0.02
	b.size_depth = 10.0
	b.size_width = 8.0
	b.roof_shape = shape
	main.nav_region.add_child(b)
	return b

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
		main.player.set_physics_process(false)
		house = KitBuilding.new()
		house.position = base
		house.floor_y = 0.02
		house.size_depth = 10.0
		house.size_width = 8.0
		house.roof_shape = "Gable"
		house.attic = "Walk-in"
		var flights: Array[KitStair] = [KitStair.make(0, Vector2(1.5, 0.0), 0.0)] # under the ridge: headroom
		house.stairs = flights
		var d: Array[KitDormer] = [KitDormer.make(Vector2(5.0, -4.0))]
		house.dormers = d
		var c: Array[KitChimney] = [KitChimney.make(Vector2(8.0, 2.5))]
		house.chimneys = c
		main.nav_region.add_child(house)
		ell = KitBuilding.new()
		ell.position = base + Vector3(0, 0, 30)
		ell.floor_y = 0.02
		ell.footprint = PackedVector2Array([Vector2(0, -6), Vector2(0, 6), Vector2(6, 6), Vector2(6, 0), Vector2(14, 0), Vector2(14, -6)])
		ell.roof_shape = "Hip"
		main.nav_region.add_child(ell)
		odd = KitBuilding.new()
		odd.position = base + Vector3(30, 0, 0)
		odd.footprint = PackedVector2Array([Vector2(0, -4), Vector2(0, 4), Vector2(6, 6), Vector2(10, -4)])
		odd.roof_shape = "Gable"
		main.nav_region.add_child(odd)
		closed = make(base + Vector3(30, 0, 30), "Gambrel")
		var up: Array[KitStair] = [KitStair.make(0, Vector2(1.5, -2.5), 0.0)]
		closed.stairs = up
		for s in ["Hip", "Shed"]:
			make(base + Vector3(60, 0, 30 if s == "Hip" else 0), s)
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		main.fortifications.rebake()
	if f == 5:
		check(house._get_configuration_warnings().is_empty(), "no warnings (%s)" % [house._get_configuration_warnings()])
		var attic_floor := down(house, 7.0, 1.5, 4.5)
		check(absf(attic_floor - 3.6) < 0.05, "an attic floor (%.2f)" % attic_floor)
		var ridge := 3.6 + 4.0 * tan(deg_to_rad(35))
		var top := down(house, 6.0, 0.0, 20.0)
		check(absf(top - ridge) < 0.3, "the ridge %.2f m up (want about %.2f)" % [top, ridge])
		var eave := down(house, 6.0, -4.2, 20.0, 2.0)
		check(eave > 3.0 and eave < 3.8, "the roof overhangs the wall (%.2f just outside it)" % eave)
		var hole := down(house, 4.5, 0.0, 4.5)
		check(hole > 0.5 and hole < 3.4, "the stairs come up through the attic floor (%.2f)" % hole)
		check(house.find_children("*", "Node3D", true, false).any(func(n): return n is KitProp and n.get_parent() == house) or house.get_children(true).any(func(n): return n is KitProp),
				"the dormer has a window")
		var chimney_top := down(house, 8.0, 2.5, 30.0)
		check(chimney_top > ridge + 0.5, "the chimney stands above the ridge (%.2f)" % chimney_top)
		var ell_top := down(ell, 3.0, 3.0, 20.0)
		var ell_main := down(ell, 10.0, -3.0, 20.0)
		check(ell_top > 4.5 and ell_main > 4.5, "the L's wing and main block both have their roof (%.2f, %.2f)" % [ell_top, ell_main])
		check(Array(odd._get_configuration_warnings()).any(func(w): return "right angles" in w), "an angled outline: a warning, and a flat roof")
		check(absf(down(odd, 5.0, 0.0, 20.0) - 3.6) < 0.05, "...flat at 3.60")
		check(Array(closed._get_configuration_warnings()).any(func(w): return "no walk-in attic" in w), "stairs up to a closed attic: a warning")
		# Someone walks up to the attic; someone else lands on the roof.
		body = capsule()
		body.global_position = house.global_transform * Vector3(1.0, 0.1, 0.0)
		faller = capsule()
		faller.global_position = house.global_transform * Vector3(5.0, 9.0, -2.0)
	if f > 5 and f < 400:
		body.velocity = house.global_basis.x * 2.0 + Vector3(0, body.velocity.y - 9.8 / 60.0, 0)
		body.move_and_slide()
		faller.velocity.y -= 9.8 / 60.0
		faller.velocity.x = 0.0; faller.velocity.z = 0.0
		faller.move_and_slide()
	if f == 400:
		check(body.global_position.y - base.y > 3.5, "walked up into the attic (%.2f m up)" % (body.global_position.y - base.y))
		var roof_y := 3.6 + 2.0 * tan(deg_to_rad(35))
		check(faller.global_position.y - base.y > roof_y - 0.5, "landed on the roof and stays there (%.2f m up, roof %.2f)" % [faller.global_position.y - base.y, roof_y])
	if baked_at > 0 and f >= 400 and f > baked_at + 70:
		var map: RID = main.get_world_3d().navigation_map
		var from: Vector3 = house.global_transform * Vector3(2.0, 0.05, 2.0)
		var to: Vector3 = house.global_transform * Vector3(8.5, 3.65, 0.0)
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var end: Vector3 = path[path.size() - 1] if path.size() else Vector3.INF
		check(end.distance_to(to) < 0.8, "a path up to the attic (%d points)" % path.size())
		print("FAILS: %d" % fails)
		return true
	return f > 1500
