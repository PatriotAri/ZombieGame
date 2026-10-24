extends SceneTree
## Phase 2 on test-only terrain: slopes slow you (zombies more), too steep can't
## be climbed, shallow water slows, deep water is swimming (no guns), zombies
## drown, and crouching in cover hides you.
const Water := preload("res://world/water.gd")
var main: Node
var f := 0
var fails := 0
var step := ""
var t0 := 0
var p0 := Vector3.ZERO
var z: Node
var pool: Node3D
var cover: Node3D
var notes: Array[String] = []

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

## Test terrain in region (1, -2) (x 256..512, z -512..-256): a 30 degree ramp
## along +x from x=300, a 50 degree wall from x=400, a pool dug at z -300.
func _sculpt() -> void:
	var data = main.terrain.data
	for x in range(280, 460):
		for zz in range(-470, -430):
			var h := 0.0
			if x >= 300: h = minf(x - 300, 60) * tan(deg_to_rad(30.0))
			data.set_height(Vector3(x, 0, zz), h)
	for x in range(280, 330): # the 50 degree wall, on its own strip
		for zz in range(-420, -400):
			data.set_height(Vector3(x, 0, zz), maxf(x - 300, 0) * tan(deg_to_rad(50.0)))
	for x in range(300, 340): # the pool: 10 m shallow (ground 0, water 1 m), then deep (ground -2)
		for zz in range(-330, -290):
			data.set_height(Vector3(x, 0, zz), 0.0 if x < 320 else -2.0)
	data.update_maps(0, true, false)
	main.terrain.collision.build()
	main.nav_region._terrain_faces.clear() # the terrain changed: re-bake from it
	main.nav_region.rebake_all()

func _make_pool() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nfunc surface_at(p: Vector3) -> float:\n\treturn 1.0 if p.x > 300.0 and p.x < 340.0 and p.z > -330.0 and p.z < -290.0 else NAN\nfunc water_rect() -> Rect2:\n\treturn Rect2(300, -330, 40, 40)\n"
	script.reload()
	pool = Node3D.new(); pool.set_script(script); pool.add_to_group("water")
	main.add_child(pool)
	var cs := GDScript.new()
	cs.source_code = "extends Node3D\nfunc covers(p: Vector3) -> bool:\n\treturn p.x > 150.0 and p.x < 160.0 and p.z > -350.0 and p.z < -340.0\n"
	cs.reload()
	cover = Node3D.new(); cover.set_script(cs); cover.add_to_group("cover")
	main.add_child(cover)

func _put_player(pos: Vector3, yaw: float) -> void:
	var p = main.player
	p.global_position = pos
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO

func _walk(on: bool) -> void:
	if on: Input.action_press("move_forward")
	else: Input.action_release("move_forward")

## Facing +x: forward is -z, so yaw -PI/2.
const EAST := -PI / 2.0

func _physics_process(_d: float) -> bool:
	f += 1
	var p = main.player
	p.health = p.max_health
	match f:
		60:
			for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
			main.day_night.hour = 12.0; main.day_night.seconds_per_game_hour = 1e9
			_sculpt(); _make_pool()
			p.notify.connect(func(t: String) -> void: notes.append(t))
		70: # flat walk speed
			_put_player(Vector3(250, 0.1, -450), EAST); _walk(true)
		90: p0 = p.global_position
		150:
			var flat: float = Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length() / 1.0
			notes.append("flat %.2f" % flat)
			check(absf(flat - p.walk_speed) < 0.3, "flat walking %.2f m/s (walk_speed %.1f)" % [flat, p.walk_speed])
			_put_player(Vector3(310, 10 * tan(deg_to_rad(30.0)) + 0.2, -450), EAST)
		170: p0 = p.global_position
		230:
			var up: float = p.global_position.distance_to(p0)
			var want: float = p.walk_speed * (1.0 - p.slope_slowdown * tan(deg_to_rad(30.0)))
			check(absf(up - want) < 0.3, "30 degree climb %.2f m/s along the ground (want about %.2f)" % [up, want])
			z = main._add_zombie(Vector3(305, 5 * tan(deg_to_rad(30.0)) + 0.3, -440), null, "walker")
			z.set_physics_process(true)
			_put_player(Vector3(296, 0.1, -410), EAST)
		235:
			z.hear_noise(Vector3(350, 50 * tan(deg_to_rad(30.0)), -440), 100.0) # up the ramp
		240, 250, 260, 280:
			if f == 260: p0 = z.global_position
			var m: RID = main.get_world_3d().navigation_map
			print("    z state %d pos %s floor %s ready %s fin %s next %s target %s closest %s baking %s" % [z.state, z.global_position, z.is_on_floor(), z._navigation_ready(), z.agent.is_navigation_finished(), z.agent.get_next_path_position(), z.target, NavigationServer3D.map_get_closest_point(m, z.global_position), main.nav_region._baking.size()])
		320:
			var zs: float = z.global_position.distance_to(p0)
			var zwant: float = (z._hunt_speed() if z.state == z.State.HUNT else z.speed) * (1.0 - z.SLOPE_SLOWDOWN * tan(deg_to_rad(30.0)))
			notes.append("z state %d" % z.state)
			check(absf(zs - zwant) < 0.2, "zombie walking up 30 degrees: %.2f m/s (want about %.2f; hunt speed %s)" % [zs, zwant, z._hunt_speed()])
			z.die(false)
			z.global_position = Vector3(-900, 0, 900)
		400:
			check(p.global_position.y < 3.0, "50 degree slope can't be climbed: got up to y %.2f" % p.global_position.y)
			_put_player(Vector3(305, 0.1, -310), EAST); _walk(false)
		420:
			check(p.water_depth > 0.8 and not p.swimming, "wading in 1 m of water (depth %.2f, swimming %s)" % [p.water_depth, p.swimming])
			_walk(true)
		430: p0 = p.global_position
		460:
			var wade: float = Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length() / 0.5
			check(absf(wade - p.walk_speed * p.wade_speed_factor) < 0.4, "wading %.2f m/s (want about %.2f)" % [wade, p.walk_speed * p.wade_speed_factor])
			_walk(false)
			_put_player(Vector3(330, -1.9, -310), EAST)
		560:
			check(p.swimming, "deep water: swimming")
			check(absf(p.global_position.y - (1.0 - Water.SWIM_DEPTH)) < 0.25, "floating chest-deep (feet at %.2f, want %.2f)" % [p.global_position.y, 1.0 - Water.SWIM_DEPTH])
			p.give_item("pistol", 1) if not p.inventory.has("pistol") else null
			p.held = "pistol"
			p._use_held()
			check(notes.has("You can't shoot while swimming."), "no shooting while swimming")
			z = main._add_zombie(Vector3(332, -1.9, -305), null, "walker")
			z.set_physics_process(true)
			t0 = f
			_put_player(Vector3(150, 0.1, -500), 0.0)
		830:
			check(z.is_dead, "zombie in deep water drowned (dead after %.1f s: %s)" % [(f - t0) / 60.0, z.is_dead])
			# Cover: crouched in the cover area, a zombie 10 m off looking right at you.
			_put_player(Vector3(155, 0.1, -345), 0.0)
			Input.action_press("crouch")
			z = main._add_zombie(Vector3(155, 0.1, -335), null, "walker")
			z.look_at(Vector3(155, 0.1, -345))
		900:
			check(p.in_cover, "crouched in cover: in_cover")
			check(z.state != z.State.HUNT, "zombie 10 m away doesn't see you in cover (state %d)" % z.state)
			Input.action_release("crouch")
		980:
			check(not p.in_cover and z.state == z.State.HUNT, "standing up: seen (state %d)" % z.state)
			print("FAILS: %d" % fails)
			return true
	return false
