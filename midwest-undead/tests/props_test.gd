extends SceneTree
## Prop models: furniture shows its stand-in (fitted to Size, painted), a model's
## own collision shapes replace the box, the random pick is the same for the
## same spot, containers darken, buildings' doors and windows (and their Door /
## Window Models), planks and barricades, things you build (fence, gate, guard
## post and ladder, garden, bench, camp kit) and the preview, and the static
## merge leaves moving things alone.
const KitBuilding := preload("res://world/building.gd")
const StaticMerge := preload("res://world/static_merge.gd")
const WindowPane := preload("res://world/window_pane.gd")
var main: Node
var f := 0
var fails := 0
var c := Vector3.ZERO
var built := {}
var house: Node3D

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func g(x: float, z: float) -> Vector3:
	return Vector3(x, main.terrain.data.get_height(Vector3(x, 0, z)), z)

## A model scene made here: a 1 m cube mesh named Paint and (with_shape) a collision box.
func model_scene(color: Color, with_shape: bool) -> PackedScene:
	var r := Node3D.new(); r.name = "M"
	var m := MeshInstance3D.new(); m.name = "PaintBody"; var bm := BoxMesh.new(); bm.size = Vector3.ONE
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; bm.material = mat; m.mesh = bm; m.position.y = 0.5
	r.add_child(m); m.owner = r
	if with_shape:
		var body := StaticBody3D.new(); body.name = "Col"; r.add_child(body); body.owner = r
		var cs := CollisionShape3D.new(); cs.name = "OwnShape"; var bs := BoxShape3D.new(); bs.size = Vector3(0.5, 0.5, 0.5); cs.shape = bs
		body.add_child(cs); cs.owner = r
	var ps := PackedScene.new(); ps.pack(r); r.free()
	return ps

## Vertices in a look (flattened in the game: many boxes, few meshes).
func verts(prop: KitProp) -> int:
	var n := 0
	for m in prop.meshes():
		for i in m.mesh.get_surface_count():
			n += (m.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n

func look_box(prop: KitProp) -> AABB:
	return KitProp._bounds(prop.look, Transform3D.IDENTITY) if prop.look else AABB()

func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		3:
			main.player.set_physics_process(false)
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(900, 0, 900)
			c = g(60, -60)
			# Furniture: every scene in the kit.
			var i := 0
			for file in DirAccess.get_files_at("res://world/kit/furniture/"):
				if not file.ends_with(".tscn"): continue
				var piece: Node3D = load("res://world/kit/furniture/" + file).instantiate()
				piece.position = c + Vector3(i * 3.0, 0, 0)
				main.add_child(piece)
				built[file] = piece
				i += 1
			# A table with a model that has its own collision.
			var table: Node3D = load("res://world/kit/furniture/table.tscn").instantiate()
			var own_models: Array[PackedScene] = [model_scene(Color.RED, true)]
			table.models = own_models
			table.position = c + Vector3(0, 0, 6)
			main.add_child(table)
			built["own"] = table
			var blue: Node3D = load("res://world/kit/furniture/car.tscn").instantiate()
			blue.material = load("res://world/kit/materials/car_blue.tres")
			blue.position = c + Vector3(0, 0, 12)
			main.add_child(blue)
			built["blue_car"] = blue
			# A building, with its own window models.
			house = KitBuilding.new()
			house.position = c + Vector3(0, 0, 30)
			house.size_depth = 8.0; house.size_width = 9.0; house.floors = 1
			house.default_openings()
			var win_models: Array[PackedScene] = [model_scene(Color.GREEN, false)]
			house.window_models = win_models
			main.nav_region.add_child(house)
		5:
			var all_ok := true
			for file: String in built:
				if not file.ends_with(".tscn"): continue
				var piece: Node3D = built[file]
				var prop: KitProp = piece.find_children("*", "Node3D", true, false).filter(func(n): return n is KitProp).front() if true else null
				var size: Vector3 = piece.size
				var box := look_box(prop).size * prop.look.scale if prop and prop.look else Vector3.ZERO
				var fits := box.distance_to(size) < 0.05
				var shaped := prop != null and prop.look != null and prop.look.name == "Model" and verts(prop) > 24
				# Solid, or not if it's set so (chairs, stools, the playground: walked through).
				var solid: bool = piece.get_children(true).any(func(n): return n is CollisionShape3D) != (piece.get("solid") == false)
				if not (fits and shaped and solid):
					print("    %s: fits %s (%s vs %s) shaped %s solid %s" % [file, fits, box, size, shaped, solid])
					all_ok = false
			check(all_ok, "every furniture piece shows its shaped stand-in, fitted to its Size, and is solid")
			var own: Node3D = built["own"]
			var shapes := own.get_children(true).filter(func(n): return n is CollisionShape3D)
			check(shapes.size() == 1 and shapes[0].name == "OwnShape", "a model with collision shapes: those, not the box (%s)" % [shapes.map(func(n): return n.name)])
			var car_prop: KitProp = built["blue_car"].get_children(true).filter(func(n): return n is KitProp)[0]
			var paint: MeshInstance3D = car_prop.meshes().filter(func(m): return m.name == "Paint")[0]
			check(paint.material_override == built["blue_car"].material, "the car's Material paints its Paint meshes (blue)")
			# The pick: the same spot always gets the same one; spots differ.
			var a := model_scene(Color.RED, false)
			var b := model_scene(Color.BLUE, false)
			check(KitProp.pick([a, b], Vector3(3, 0, 4)) == KitProp.pick([a, b], Vector3(3, 0, 4)), "the same spot always picks the same model")
			var seen := {}
			for k in 20:
				seen[KitProp.pick([a, b], Vector3(k * 1.7, 0, k * 0.9))] = true
			check(seen.size() == 2, "different spots pick different ones")
			# A container darkens when opened.
			var crate: KitContainer = built["supply_crate.tscn"]
			crate.open()
			var crate_prop: KitProp = crate.get_children(true).filter(func(n): return n is KitProp)[0]
			check(crate_prop.meshes()[0].material_overlay != null, "searched: the crate darkens")
			# The building's door and windows.
			var doors := house.find_children("*", "AnimatableBody3D", true, false)
			var panes := house.find_children("*", "StaticBody3D", true, false).filter(func(n): return n is WindowPane)
			check(doors.size() == 1 and doors[0]._look != null and doors[0]._look.look.name == "StandIn", "the building's door: the door prop's stand-in")
			var door = doors[0]
			var leaf_box: Vector3 = look_box(door._look).size * door._look.look.scale
			check(leaf_box.distance_to(door.leaf_size) < 0.05, "...stretched to the doorway (%s)" % leaf_box)
			check(door.get_children(true).any(func(n): return n is CollisionShape3D), "...and solid")
			door.bash(50.0)
			check(door._look.meshes()[0].material_overlay != null, "bashed: it darkens")
			check(panes.size() >= 2 and panes.all(func(p): return p._look.look.name == "Model"), "its windows: the building's Window Models (%d)" % panes.size())
			var plain := KitBuilding.new()
			plain.position = c + Vector3(20, 0, 30)
			plain.size_depth = 8.0; plain.size_width = 9.0; plain.floors = 1
			plain.default_openings()
			main.nav_region.add_child(plain)
			var pane = plain.find_children("*", "StaticBody3D", true, false).filter(func(n): return n is WindowPane)[0]
			var glass: Node3D = pane._look.look.get_node("Glass")
			pane.smash(true)
			check(not glass.visible and pane._look.look.visible, "a smashed window: the glass goes, the frame stays")
			# Planks and a barricade.
			var o := {"kind": "window", "width": 1.2, "height": 1.4, "transform": Transform3D(Basis(), c + Vector3(0, 1.5, -10))}
			var planks = main.fortifications._make_planks(o)
			var pl: KitProp = planks.get_children().filter(func(n): return n is KitProp)[0]
			check(verts(pl) >= 3 * 24 and planks.get_children().any(func(n): return n is CollisionShape3D), "planks over a window: boards and a box")
			check(absf((look_box(pl).size * pl.look.scale).z - 1.5) < 0.05, "...as wide as the opening plus a bit")
			main.fortifications.place_barricade(Transform3D(Basis(), g(70, -50)), true)
			check(main.fortifications.barricades[-1].get_children().any(func(n): return n is KitProp), "a barricade has its look")
			# Things you build.
			var S = main.structures
			built["fence"] = S.build("fence", Transform3D(Basis(), g(80, -60)), null, true)
			built["gate"] = S.build("fence_gate", Transform3D(Basis(), g(84, -60)), null, true)
			built["scaffold"] = S.build("scaffold", Transform3D(Basis(), g(88, -60)), null, true)
			built["post"] = S.build("guard_post", Transform3D(Basis(), built["scaffold"].global_position + Vector3(0, 3.0, 0)), built["scaffold"], true)
			built["garden"] = S.build("garden_plot", Transform3D(Basis(), g(92, -60)), null, true)
			built["bench"] = S.build("rifle_bench", Transform3D(Basis(), g(96, -60)), null, true)
			built["camp"] = S.build("camp_kit", Transform3D(Basis(), g(110, -80)), null, true)
		7:
			var S = main.structures
			for k in ["fence", "gate", "scaffold", "post", "garden", "bench"]:
				var p: Node3D = built[k]
				var has_look: bool = p.get_children().any(func(n): return n is KitProp and n.meshes().size() > 0)
				var solid: bool = p.get_children().any(func(n): return n is CollisionShape3D)
				check(has_look and solid, "built %s: its look and its collision" % k)
			check(built["gate"].leaf.get_children().any(func(n): return n is KitProp) and built["gate"].leaf.get_children().any(func(n): return n is CollisionShape3D), "the gate's leaf: look and collision")
			var ladder: KitProp = built["post"].get_node("Ladder")
			check(ladder != null and absf((look_box(ladder).size * ladder.look.scale).y - 4.0) < 0.1, "the guard post's ladder reaches the ground (%.1f m)" % (look_box(ladder).size * ladder.look.scale).y)
			var camp: Node3D = built["camp"]
			check(camp.get_node_or_null("Logbook") != null and camp.get_node_or_null("Board") != null and camp.get_node_or_null("Crate") != null, "the camp kit: logbook, board and crate")
			check((camp.get_node("Crate") as KitContainer).inventory.is_empty(), "...its crate starts empty")
			check(camp.find_children("*", "OmniLight3D", true, false).size() == 1, "...and a campfire glowing")
			S.plate(built["fence"], true)
			check(built["fence"].get_children().filter(func(n): return n is KitProp).size() == 2, "plating a fence adds its plates")
			built["gate"].health = 1.0
			S.damaged(built["gate"], true)
			built["gate"].health = 0.0
			S._break(built["gate"], true)
			var wreck: Array = built["gate"].get_children().filter(func(n): return n is KitProp)
			check(wreck.size() == 1 and built["gate"].leaf == null, "a broken gate: just the wreck")
			S.show_ghost("guard_post", {"xform": Transform3D(Basis(), g(100, -70)), "ok": true, "ladder": 3.0})
			var ghost_meshes: Array = S._ghost.find_children("*", "MeshInstance3D", true, false)
			check(ghost_meshes.size() >= 2 and ghost_meshes.all(func(m): return m.material_override == S._ghost_material), "the preview: see-through, ladder and all")
			S.show_ghost("camp_kit", {"xform": Transform3D(Basis(), g(100, -70)), "ok": false})
			check(S._ghost.find_children("*", "OmniLight3D", true, false).all(func(l): return not l.visible), "the camp preview's fire doesn't light up")
			# The static merge: kit boxes' looks merged, containers and doors left alone.
			var town := Node3D.new()
			main.add_child(town)
			var table: Node3D = load("res://world/kit/furniture/table.tscn").instantiate()
			var dresser: Node3D = load("res://world/kit/furniture/dresser.tscn").instantiate()
			town.add_child(table); town.add_child(dresser)
			dresser.position.x = 3
			StaticMerge.merge(town)
			var table_hidden: bool = table.find_children("*", "MeshInstance3D", true, false).all(func(m): return not m.visible)
			var dresser_shown: bool = dresser.find_children("*", "MeshInstance3D", true, false).all(func(m): return m.visible)
			check(table_hidden and dresser_shown, "merging: a table's stand-in is merged, a dresser (a container) isn't")
			print("FAILS: %d" % fails)
			return true
	return f > 600
