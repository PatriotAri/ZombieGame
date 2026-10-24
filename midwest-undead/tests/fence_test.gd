extends SceneTree
## Breakable fences and gates: bashing, darkening, breaking into a wreck you can
## walk through and take down, plating, repair, save/load, zombies bashing one
## that's between them and a noise (and wanderers leaving it alone); the jump;
## the machinist's sheet metal recipe.
const StructurePiece := preload("res://world/structure_piece.gd")
const Recipes := preload("res://core/recipes.gd")
const GameData := preload("res://core/game_data.gd")
var main: Node
var f := 0
var fails := 0
var c := Vector3.INF
var ring: Array = []
var z: Node
var wander: Node
var wander_fence: Node
var start_f := 0
var jump_peak := 0.0
var jump_start_y := 0.0
var jump_air := 0
var jump_f := 0
var broke_at := -1
var got_in := false
func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1
func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func _open_spot() -> Vector3:
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(14, 2.4, 14)
	var map: RID = main.get_world_3d().navigation_map
	var spots := []
	for x in range(-160, 161, 8):
		for zz in range(-160, 161, 8):
			spots.append(Vector2(x, zz))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length() < b.length())
	for s: Vector2 in spots:
			var x := s.x
			var zz := s.y
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.collision_mask = GameData.LAYER_WORLD
			q.transform = Transform3D(Basis(), Vector3(x, 1.4, zz))
			if space.intersect_shape(q, 1).is_empty():
				var down := PhysicsRayQueryParameters3D.create(Vector3(x, 5, zz), Vector3(x, -2, zz), GameData.LAYER_WORLD)
				var hit := space.intersect_ray(down)
				var near := NavigationServer3D.map_get_closest_point(map, Vector3(x, 0, zz + 8))
				if not hit.is_empty() and absf(hit["position"].y) < 0.3 and near.distance_to(Vector3(x, 0, zz + 8)) < 0.6:
					return Vector3(x, hit["position"].y, zz)
	return Vector3.INF

func _physics_process(_d: float) -> bool:
	return _step()

func _step() -> bool:
	f += 1
	if main.player:
		main.player.health = main.player.max_health
	var S = main.structures
	if f == 80:
		c = _open_spot()
		check(c != Vector3.INF, "open spot %s" % c)
		for q in main.zombies:
			q.set_physics_process(false); q.global_position = Vector3(900, 0, 900)
		main.player.set_physics_process(false)
		main.player.global_position = c + Vector3(30, 0.2, 30)
		# --- Unit checks on one fence and one gate
		var fence = S.build("fence", Transform3D(Basis(), c + Vector3(0, 0, -5)), null, true)
		var gate = S.build("fence_gate", Transform3D(Basis(), c + Vector3(4, 0, -5)), null, true)
		check(fence.can_be_bashed() and gate.leaf.can_be_bashed(), "fence and shut gate can be bashed")
		S.toggle_gate(gate, true)
		check(not gate.leaf.can_be_bashed(), "open gate can't be bashed")
		S.toggle_gate(gate, true)
		var mesh: MeshInstance3D = fence.find_children("*", "MeshInstance3D", true, false)[0]
		fence.bash(StructurePiece.MAX_HEALTH * 0.5)
		check(mesh.material_overlay != null, "half-health fence is darker")
		var shade_a: float = mesh.material_overlay.albedo_color.a
		fence.bash(StructurePiece.MAX_HEALTH * 0.3)
		check(mesh.material_overlay.albedo_color.a > shade_a, "more damage, darker still")
		check(fence.is_damaged(), "fence is damaged")
		S.repair(fence)
		check(is_equal_approx(fence.health, StructurePiece.MAX_HEALTH * 0.2 + 2500.0), "one plank repairs 2500 (%.0f)" % fence.health)
		# Plate the gate: unbreakable, metal on the leaf
		gate.bash(1000.0)
		var leaf_meshes: int = gate.leaf.find_children("*", "MeshInstance3D", true, false).size()
		S.plate(gate, true)
		check(gate.plated and not gate.can_be_bashed() and not gate.leaf.can_be_bashed() and gate.health == StructurePiece.MAX_HEALTH, "plated gate: full health, can't be bashed")
		check(gate.leaf.find_children("*", "MeshInstance3D", true, false).size() > leaf_meshes, "plates added on the leaf")
		gate.bash(99999.0)
		check(not gate.broken, "plated gate survives any bash")
		# Break the fence
		fence.bash(99999.0)
		check(fence.broken and fence.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D).is_empty(), "fence broke: no collision left")
		var area: Array = fence.get_children().filter(func(n: Node) -> bool: return n is Area3D)
		check(area.size() == 1 and area[0].collision_layer == GameData.LAYER_ITEMS, "wreck has a look-at area")
		check(fence.interact_prompt().begins_with("take down the broken"), "wreck prompt: %s" % fence.interact_prompt())
		check(not fence.can_be_bashed() and not fence.is_damaged(), "wreck can't be bashed or repaired")
		# Save and load
		var saved: Array = S.save_state()
		var fence_entry: Dictionary = saved[S.pieces.find(fence)]
		var gate_entry: Dictionary = saved[S.pieces.find(gate)]
		check(fence_entry["broken"] == true and gate_entry["plated"] == true, "saved broken/plated")
		var dmg = S.build("fence", Transform3D(Basis(), c + Vector3(-4, 0, -5)), null, true)
		dmg.bash(3000.0)
		saved = S.save_state()
		for p in S.pieces.duplicate():
			S.take_down(p)
		S.load_state(saved)
		var by_x := {}
		for p in S.pieces:
			by_x[roundi(p.global_position.x - c.x)] = p
		check(by_x[0].broken and by_x[0].kind == "fence", "loaded wreck")
		check(by_x[4].plated and by_x[4].leaf != null and by_x[4].leaf.find_children("*", "MeshInstance3D", true, false).size() > leaf_meshes, "loaded plated gate with its plates")
		check(is_equal_approx(by_x[-4].health, StructurePiece.MAX_HEALTH - 3000.0), "loaded damaged fence health %.0f" % by_x[-4].health)
		# Take-down returns
		var back: Dictionary = S.take_down(by_x[0])
		check(back == {"used_planks": 2}, "wreck gives %s" % back)
		back = S.take_down(by_x[4])
		check(back == {"fence_gate": 1, "sheet_metal": 3}, "plated gate gives %s" % back)
		back = S.take_down(by_x[-4])
		check(back == {"fence": 1}, "damaged fence gives %s" % back)
		# Plating through the player: needs sheets, takes them
		var pf = S.build("fence", Transform3D(Basis(), c + Vector3(0, 0, -5)), null, true)
		main.player.global_position = c + Vector3(0, 0, -3)
		main.player.rotation.y = 0.0
		main.player.camera.rotation.x = deg_to_rad(-20)
		main.player.give_item("sheet_metal", 1)
		print("    aimed: ", main.player.building._aimed_piece())
		main.player.building.try_plate()
		check(pf.plated and main.player.inventory.count("sheet_metal") == 0, "player plates a fence with 1 sheet")
		main.player.global_position = c + Vector3(30, 0.2, 30)
		S.take_down(pf)
		# Machinist recipe
		check(Recipes.MACHINIST_ANYTIME.size() == 1 and Recipes.MACHINIST_ANYTIME[0]["id"] == "sheet_metal" and Recipes.MACHINIST_ANYTIME[0]["needs"] == {"scrap_metal": 10}, "sheet metal: 10 scrap")
		check(GameData.item("sheet_metal") != null and GameData.item("sheet_metal").use_kind() == "plate", "sheet_metal item, use plate")
		# --- Zombie scenario: a ring of fences around a noise
		for spec in [[Vector3(0, 0, 1.5), 0.0], [Vector3(0, 0, -1.5), 0.0], [Vector3(1.5, 0, 0), PI / 2], [Vector3(-1.5, 0, 0), PI / 2]]:
			var p = S.build("fence", Transform3D(Basis(Vector3.UP, spec[1]), c + spec[0]), null, true)
			p.health = 300.0 # quick to break for the test
			ring.append(p)
		wander_fence = S.build("fence", Transform3D(Basis(), c + Vector3(-12, 0, 6)), null, true)
		main.fortifications.rebake()
	if f == 200:
		z = main._add_zombie(c + Vector3(6, 0.1, 0.5), null, "walker")
		wander = main._add_zombie(c + Vector3(-12, 0.1, 6.8), null, "walker")
		start_f = f
	if f == 260:
		z.hear_noise(c, 50.0)
	if f > 260 and f < 260 + 60 * 30 and broke_at < 0:
		for p in ring:
			if p.broken:
				broke_at = f
		if f % 120 == 0:
			print("    %ds: state %d pos %s healths %s" % [(f - 260) / 60, z.state, z.global_position - c, ring.map(func(p): return int(p.health))])
	if broke_at > 0 and f < 260 + 60 * 30 and absf(z.global_position.x - c.x) < 1.3 and absf(z.global_position.z - c.z) < 1.3:
		got_in = true
	if false:
		print("    +%.2fs after break: state %d pos %s linger %.2f baking %s" % [(f - broke_at) / 60.0, z.state, z.global_position - c, z.linger_timer, main.fortifications._baking])
	if f == 260 + 60 * 30:
		check(broke_at > 0, "investigating zombie broke a ring fence (after %.1f s)" % ((broke_at - 260) / 60.0))
		check(wander_fence.health == StructurePiece.MAX_HEALTH, "wandering zombie left its fence alone")
		check(got_in, "zombie went through the gap to the noise")
		# --- Jump
		for q in [z, wander]:
			q.set_physics_process(false); q.global_position = Vector3(900, 0, 900)
		for p in S.pieces.duplicate():
			S.take_down(p)
		main.player.global_position = c + Vector3(0, 0.1, 8)
		main.player.set_physics_process(true)
	if f == 260 + 60 * 31:
		jump_start_y = main.player.global_position.y
		Input.action_press("jump")
		jump_f = f
	if jump_f > 0 and f == jump_f + 2:
		Input.action_release("jump")
	if jump_f > 0 and f > jump_f:
		jump_peak = maxf(jump_peak, main.player.global_position.y - jump_start_y)
		if not main.player.is_on_floor():
			jump_air += 1
	if jump_f > 0 and f == jump_f + 120:
		check(absf(jump_peak - 0.75) < 0.08, "jump height %.2f m (want ~0.75)" % jump_peak)
		check(absf(jump_air / 60.0 - 0.55) < 0.08, "air time %.2f s (want ~0.55)" % (jump_air / 60.0))
		print("FAILS: %d" % fails)
		return true
	return false
