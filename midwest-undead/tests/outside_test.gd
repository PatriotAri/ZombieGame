extends SceneTree
## Building tools phase 4: porches (roofed and wrapped round a corner, screened,
## an open stoop), a garage door (can't be broken; zombies only get past it
## open), and a basement with a cellar door (the ground opened for it, dark
## inside, walked down into, reached by the navigation).
const KitBuilding := preload("res://world/building.gd")
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
var main: Node
var f := 0
var porch: Node3D
var garage: Node3D
var cellar: Node3D
var odd: Node3D
var walkers := {} # name -> [body, velocity]
var baked_at := -1
var phase := 0
var shut_at := -1
var fails := 0
var base := Vector3(-110, 0, -70)

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, TerrainEdit.height_at(main.terrain, at), at.z)

func ray(b: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(b.global_transform * from, b.global_transform * to)
	return root.get_world_3d().direct_space_state.intersect_ray(q)

func down(b: Node3D, x: float, z: float, from_y: float, to_y := -6.0) -> float:
	var hit := ray(b, Vector3(x, from_y, z), Vector3(x, to_y, z))
	return b.to_local(hit["position"]).y if not hit.is_empty() else -99.0

func walker(name: String, b: Node3D, at: Vector3, dir: Vector3) -> void:
	var c := CharacterBody3D.new()
	var shape := CapsuleShape3D.new(); shape.radius = 0.35; shape.height = 1.75
	var col := CollisionShape3D.new(); col.shape = shape; col.position.y = 0.875
	c.add_child(col)
	c.floor_max_angle = deg_to_rad(46)
	root.add_child(c)
	c.global_position = b.global_transform * at
	walkers[name] = [c, b.global_basis * dir * 2.0]

func path_end(from: Vector3, to: Vector3) -> Vector3:
	var path := NavigationServer3D.map_get_path(main.get_world_3d().navigation_map, from, to, true)
	return path[path.size() - 1] if path.size() else Vector3.INF

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
		main.player.set_physics_process(false)
		# A wraparound roofed porch on a raised house.
		porch = KitBuilding.new()
		porch.position = ground(base)
		porch.floor_y = 0.4
		porch.size_depth = 10.0; porch.size_width = 10.0
		porch.roof_shape = "Gable"
		porch.default_openings()
		var p1: Array[KitPorch] = [KitPorch.make(PackedInt32Array([0, 1]))]
		porch.porches = p1
		main.nav_region.add_child(porch)
		# A garage door in the side of a house, a screened porch out back, a stoop at the front.
		garage = KitBuilding.new()
		garage.position = ground(base + Vector3(0, 0, 30))
		garage.floor_y = 0.02
		garage.size_depth = 10.0; garage.size_width = 10.0
		garage.default_openings()
		var ops: Array[KitOpening] = garage.openings.duplicate()
		ops.append(KitOpening.make("left", "garage door", 0.0, 2.8, 0.0, 2.3))
		garage.openings = ops
		var scr := KitPorch.make(PackedInt32Array([2]), "Screened")
		scr.length = 6.0
		var stoop := KitPorch.make(PackedInt32Array([0]), "Open")
		stoop.length = 3.0; stoop.depth = 1.6
		var p2: Array[KitPorch] = [scr, stoop]
		garage.porches = p2
		main.nav_region.add_child(garage)
		# A basement, a cellar door on the right wall, stairs up inside.
		cellar = KitBuilding.new()
		cellar.position = ground(base + Vector3(30, 0, 0))
		cellar.floor_y = 0.2
		cellar.size_depth = 10.0; cellar.size_width = 10.0
		cellar.basement = true
		cellar.default_openings()
		var cd: Array[KitCellarDoor] = [KitCellarDoor.make(1, 0.0)]
		cellar.cellar_doors = cd
		var up: Array[KitStair] = [KitStair.make(-1, Vector2(1.5, -3.5), 0.0)]
		cellar.stairs = up
		main.nav_region.add_child(cellar)
		cellar.apply(main.terrain)
		main.nav_region._terrain_faces.clear() # (the game never changes the ground in play)
		# Things that warn.
		odd = KitBuilding.new()
		odd.position = base + Vector3(30, 0, 30)
		var bad: Array[KitCellarDoor] = [KitCellarDoor.make(0, 0.0)]
		odd.cellar_doors = bad
		var gap := KitPorch.make(PackedInt32Array([0, 2]))
		var p3: Array[KitPorch] = [gap]
		odd.porches = p3
		var hi := KitOpening.make("front", "garage door", 2.0, 2.8, 0.0, 2.3)
		hi.level = 1
		odd.floors = 2
		var o3: Array[KitOpening] = [hi]
		odd.openings = o3
		main.nav_region.add_child(odd)
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		main.fortifications.rebake()
	if f == 5:
		for b in [porch, garage, cellar]:
			check(b._get_configuration_warnings().is_empty(), "%s: no warnings (%s)" % [b.name, b._get_configuration_warnings()])
		var w := Array(odd._get_configuration_warnings())
		check(w.any(func(s): return "no Basement" in s), "a cellar door without a basement: a warning")
		check(w.any(func(s): return "follow on round" in s), "a porch on walls that don't follow on: a warning")
		check(w.any(func(s): return "garage door" in s and "floor 1" in s), "a garage door upstairs: a warning")
		# The porch.
		check(absf(down(porch, -1.2, -3.0, 2.0) - 0.4) < 0.05, "a deck in front at the floor's height (%.2f)" % down(porch, -1.2, -3.0, 2.0))
		check(absf(down(porch, 5.0, 6.2, 2.0) - 0.4) < 0.05, "...and round the corner along wall 1 (%.2f)" % down(porch, 5.0, 6.2, 2.0))
		check(absf(down(porch, -1.5, 6.5, 2.0) - 0.4) < 0.05, "...and across the corner")
		var over := ray(porch, Vector3(-1.2, 1.0, -3.0), Vector3(-1.2, 6.0, -3.0))
		check(not over.is_empty() and porch.to_local(over["position"]).y < 3.4, "a roof over it (%.2f)" % (porch.to_local(over["position"]).y if not over.is_empty() else -1.0))
		check(not ray(porch, Vector3(-1.2, 0.9, 3.0), Vector3(-4.0, 0.9, 3.0)).is_empty(), "a railing along its edge")
		check(ray(porch, Vector3(-1.2, 0.9, 0.0), Vector3(-4.0, 0.9, 0.0)).is_empty(), "...open at the steps")
		var step := down(porch, -2.8, 0.0, 2.0)
		check(step > 0.05 and step < 0.35, "steps down from it (%.2f)" % step)
		# The screened porch and the stoop.
		check(not ray(garage, Vector3(11.0, 1.5, 1.5), Vector3(13.5, 1.5, 1.5)).is_empty(), "screens round the screened porch")
		var screen_door: Node = garage.get_node_or_null("Porch1ScreenDoor")
		check(screen_door != null and screen_door.boardable and screen_door.can_be_bashed(), "a screen door, that can be boarded and bashed in")
		check(absf(down(garage, -0.8, 0.0, 2.0) - 0.02) < 0.05, "a stoop at the front door")
		# The garage door.
		var gd: Node = garage.get_node_or_null("LeftGarageDoor")
		check(gd != null and gd.in_navigation and not gd.can_be_bashed() and not gd.boardable, "a garage door: can't be broken or boarded, stays in the navigation")
		check(not ray(garage, Vector3(5, 1.0, -7.0), Vector3(5, 1.0, -3.0)).is_empty(), "shut, it's solid")
		var dark: Node = cellar.get_node_or_null("BasementDark")
		check(dark is ReflectionProbe and (dark as ReflectionProbe).ambient_mode == ReflectionProbe.AMBIENT_COLOR, "the basement is dark")
		# The basement.
		check(absf(down(cellar, 7.0, 2.0, -0.5) + 2.8) < 0.05, "a basement floor (%.2f)" % down(cellar, 7.0, 2.0, -0.5))
		check(absf(down(cellar, 7.0, 2.0, 2.0) - 0.2) < 0.05, "...under the ground floor")
		var v: Vector3 = cellar.global_transform * Vector3(5, 0, 0)
		var sp: float = main.terrain.vertex_spacing
		v = (v / sp).round() * sp
		check(main.terrain.data.get_control_hole(v), "the ground's open under it")
		check(not main.terrain.data.get_control_hole(cellar.global_transform * Vector3(-6, 0, 0)), "...not out front")
		var cdoor: Node = cellar.get_node_or_null("CellarDoor1")
		check(cdoor != null and cdoor.boardable and cdoor.can_be_bashed(), "a cellar door, that can be boarded and bashed in")
		var lid := down(cellar, 5.0, 7.5, 3.0)
		check(lid > 0.1 and lid < 1.1, "shut, it covers the steps (%.2f)" % lid)
		cdoor.set_open(true, false)
		gd.toggle() # (as the player does: it re-bakes round itself once it's up)
	if f == 60:
		var gd: Node = garage.get_node_or_null("LeftGarageDoor")
		print("    garage door open at ", garage.to_local(gd.global_position).snappedf(0.01), " basis ", garage.global_basis.inverse() * gd.global_basis)
		var well := down(cellar, 5.0, 7.5, 3.0)
		check(well < -0.8, "open: the steps go down into the ground (%.2f)" % well)
		var hit := ray(garage, Vector3(5, 1.0, -7.0), Vector3(5, 1.0, -3.0))
		check(hit.is_empty(), "the garage door open: a way in (%s)" % ["" if hit.is_empty() else str(hit["collider"].name) + " at " + str(garage.to_local(hit["position"]).snappedf(0.01))])
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		baked_at = -1
		main.fortifications.rebake() # (for the cellar door: an ordinary door, in the bake here)
		# Walkers: down the porch steps; off the porch's edge (the railing stops
		# them); down the cellar steps into the basement.
		walker("steps", porch, Vector3(-0.8, 0.5, 0.0), Vector3(-1, 0, 0))
		walker("edge", porch, Vector3(-0.8, 0.5, 3.0), Vector3(-1, 0, 0))
		var far := KitBuilding._cellar_length() - 0.3
		walker("cellar", cellar, Vector3(5.0, 0.3, 5.0 + far), Vector3(0, 0, -1))
	if f > 7 and f < 400 and walkers.size():
		for k in walkers:
			var c: CharacterBody3D = walkers[k][0]
			var vel: Vector3 = walkers[k][1]
			c.velocity = Vector3(vel.x, c.velocity.y - 9.8 / 60.0, vel.z)
			c.move_and_slide()
	if f == 400:
		var s: CharacterBody3D = walkers["steps"][0]
		check(porch.to_local(s.global_position).y < 0.15 and porch.to_local(s.global_position).x < -3.0, "walked down the porch steps (%s)" % porch.to_local(s.global_position).snappedf(0.01))
		var e: CharacterBody3D = walkers["edge"][0]
		check(porch.to_local(e.global_position).x > -2.6 and porch.to_local(e.global_position).y > 0.3, "the railing kept them on the porch (%s)" % porch.to_local(e.global_position).snappedf(0.01))
		var c: CharacterBody3D = walkers["cellar"][0]
		var at := cellar.to_local(c.global_position)
		check(at.y < -2.6 and at.z < 4.6, "walked down the cellar steps into the basement (%s)" % at.snappedf(0.01))
	if f >= 400 and baked_at > 0 and f > baked_at + 70 and phase == 0 and main.nav_region._dirty.is_empty() and main.nav_region._baking.is_empty():
		phase = 1
		var into_garage: Vector3 = garage.global_transform * Vector3(5.0, 0.05, -2.0)
		check(path_end(garage.global_transform * Vector3(5.0, 0.05, -9.0), into_garage).distance_to(into_garage) < 0.8, "the garage door open: a path in through it")
		var basement_floor: Vector3 = cellar.global_transform * Vector3(5.0, -2.75, 0.0)
		check(path_end(cellar.global_transform * Vector3(5.0, 0.05, 13.0), basement_floor).distance_to(basement_floor) < 0.8, "a path down the cellar steps to the basement")
		var upstairs: Vector3 = cellar.global_transform * Vector3(8.0, 0.25, 0.0)
		check(path_end(basement_floor, upstairs).distance_to(upstairs) < 0.8, "...and up the stairs inside to the ground floor")
		var on_porch: Vector3 = porch.global_transform * Vector3(-1.2, 0.45, 4.0)
		check(path_end(porch.global_transform * Vector3(-5.0, 0.05, 0.0), on_porch).distance_to(on_porch) < 0.8, "a path up the porch steps onto it")
		# Shut the garage again: no way in.
		baked_at = -1
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		garage.get_node("LeftGarageDoor").toggle() # shut: it re-bakes round itself
		phase = 1
	if phase == 1 and baked_at > 0 and f > baked_at + 70 and main.nav_region._dirty.is_empty() and main.nav_region._baking.is_empty():
		var into_garage: Vector3 = garage.global_transform * Vector3(5.0, 0.05, -2.0)
		var pth := NavigationServer3D.map_get_path(main.get_world_3d().navigation_map, garage.global_transform * Vector3(5.0, 0.05, -9.0), into_garage, true)
		print("    path: ", Array(pth).map(func(q): return garage.to_local(q).snappedf(0.1)))
		var gd: Node = garage.get_node("LeftGarageDoor")
		print("    door at ", garage.to_local(gd.global_position).snappedf(0.01), " open ", gd.is_open)
		# Boarding the cellar door: planks lie over the slanted door.
		var cdoor: Node = cellar.get_node("CellarDoor1")
		main.fortifications.setup(main.nav_region, [], [cdoor])
		var idx: int = main.fortifications.openings.size() - 1
		main.fortifications.board(idx, true)
		var planks: Node3D = main.fortifications.openings[idx]["planks"]
		var lp := cellar.to_local(planks.global_position)
		check(cdoor.boarded and not cdoor.is_open and absf(lp.x - 5.0) < 0.1 and lp.y > 0.55 and lp.y < 0.95 and lp.z > 6.7 and lp.z < 7.8,
				"boarded, the cellar door's shut and the planks lie over it (%s)" % lp.snappedf(0.01))
		check(planks.global_basis.x.y > 0.9, "...facing up")
		check(path_end(garage.global_transform * Vector3(5.0, 0.05, -9.0), into_garage).distance_to(into_garage) > 1.5, "the garage door shut: no way in (the front door's shut too)")
		print("FAILS: %d" % fails)
		return true
	return f > 2500
