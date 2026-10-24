extends SceneTree
## Phase 4 on test-only terrain: plant brushes, trunks, cover, crop fields,
## rocks, mine entrances, foundations, falling off the map.
const Plants := preload("res://world/map/plants.gd")
const PlantPainter := preload("res://world/map/plant_painter.gd")
const Cover := preload("res://world/cover.gd")
const CropField := preload("res://world/map/crop_field.gd")
const Rock := preload("res://world/map/rock.gd")
const MineEntrance := preload("res://world/map/mine_entrance.gd")
var main: Node
var t: Node
var f := 0
var fails := 0
var rng := RandomNumberGenerator.new()
var field: Node
var building: Node3D

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	rng.seed = 42
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func h(x: float, z: float) -> float:
	return t.data.get_height(Vector3(x, 0, z))

## Plants of these kinds within radius of center (world positions).
func plants_near(center: Vector3, radius: float, kinds: Array) -> Array:
	return PlantPainter._positions(t, center, radius, kinds[0]) if kinds.size() == 1 else \
			PlantPainter._positions(t, center, radius, kinds[0]) + PlantPainter._positions(t, center, radius, kinds[1])

func ray(from: Vector3, to: Vector3) -> Dictionary:
	return main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))

func _physics_process(_d: float) -> bool:
	f += 1
	main.player.health = main.player.max_health
	match f:
		60:
			t = main.terrain
			for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
			var d = t.data
			for x in range(0, 41): # a steep hill rising toward -z for the mine
				for z in range(-70, -19):
					d.set_height(Vector3(x, 0, z), clampf((-20 - z) * 1.2, 0.0, 30.0))
			for x in range(190, 215): # a slope under the building: 0 down to -3 along +x
				for z in range(-215, -190):
					d.set_height(Vector3(x, 0, z), -clampf((x - 195) * 0.3, 0.0, 3.0))
			d.update_maps(0, true, false)
			t.collision.build()
			var c := Vector3(-200, 0, 200)
			var added := PlantPainter.paint_forest(t, c, 20.0, 2.0, rng)
			var trees := plants_near(c, 25.0, ["Tree"])
			var under := plants_near(c, 25.0, ["Undergrowth"])
			check(trees.size() >= 12 and trees.size() <= 35 and under.size() > trees.size() * 1.5,
					"forest brush: %d plants, %d trees, %d undergrowth (radius 20 m, density 2)" % [added, trees.size(), under.size()])
			var too_close := 0
			for i in trees.size():
				for k in range(i + 1, trees.size()):
					if Vector2(trees[i].x - trees[k].x, trees[i].z - trees[k].z).length() < 3.9: too_close += 1
			check(too_close == 0, "trees keep their spacing (%d pairs too close)" % too_close)
			var removed := PlantPainter.erase(t, c, 8.0, ["Tree", "Undergrowth"])
			check(removed > 0 and plants_near(c, 8.0, ["Tree"]).is_empty() and plants_near(c, 8.0, ["Undergrowth"]).is_empty(),
					"erase cleared %d plants within 8 m" % removed)
			var oak: PlantData = load("res://world/map/plants/oak.tres")
			var bush: PlantData = load("res://world/map/plants/bush.tres")
			PlantPainter.place_one(t, Vector3(-150, 0, 150), oak, rng)
			PlantPainter.place_one(t, Vector3(-140, 0, 150), bush, rng)
			# What a fresh load does: trunks and cover from the painted plants.
			var holder := Node3D.new(); main.add_child(holder)
			Plants.free_trunks(main._trunks)
			main._trunks = Plants.build_trunks(t, main.get_world_3d().space, holder)
			Cover.mesh_ids = Plants.hiding_ids()
			field = CropField.new()
			field.crop = load("res://world/map/plants/corn.tres")
			field.curve = Curve3D.new()
			for p: Vector3 in [Vector3(100, 0, 100), Vector3(130, 0, 100), Vector3(130, 0, 130), Vector3(100, 0, 130)]:
				field.curve.add_point(p)
			main.town.add_child(field)
			var rock := Rock.new(); rock.shape = 7
			main.town.add_child(rock); rock.global_position = Vector3(60, 0, 60)
			var mine := MineEntrance.new()
			main.town.add_child(mine); mine.global_position = Vector3(20, 0, -20) # at the foot of the hill
			mine.apply(t)
			building = KitBuilding.new()
			building.size_depth = 8.0; building.size_width = 8.0; building.floor_y = 0.02
			main.town.add_child(building); building.global_position = Vector3(198, 0, -202)
			building.call("_build_foundation")
			main.player.global_position = Vector3(-60, 0.2, -60)
		64:
			var tr: Dictionary = ray(Vector3(-155, 1.5, 150), Vector3(-145, 1.5, 150))
			check(not tr.is_empty() and absf(tr["position"].x + 150) < 1.0, "a painted tree's trunk blocks a ray (hit at %s)" % tr.get("position", "nothing"))
			check(Cover.hides(self, Vector3(-140, 0, 150)), "crouching in a painted bush is cover")
			check(not Cover.hides(self, Vector3(-135, 0, 150)), "5 m from it isn't")
			check(field.covers(Vector3(115, 0, 115)) and not field.covers(Vector3(95, 0, 115)), "crop field is cover inside its outline only")
			var mm: MultiMesh = field.get_node("Built").multimesh
			check(mm.instance_count > 2000 and mm.instance_count < 4000, "corn in rows: %d plants" % mm.instance_count)
			field.apply(t)
			check(t.data.get_control_base_id(Vector3(115, 0, 115)) == 7 and t.data.get_control_base_id(Vector3(95, 0, 115)) != 7, "field plowed inside its outline")
			var rk: Dictionary = ray(Vector3(60, 10, 60), Vector3(60, -10, 60))
			check(not rk.is_empty() and rk["position"].y > 0.3, "rock has collision (top at %s)" % rk.get("position", "nothing"))
			check(t.data.get_control_hole(Vector3(20, 0, -22)), "mine mouth: the hillside is opened where it crosses the tunnel")
			check(not t.data.get_control_hole(Vector3(20, 0, -32)), "deeper in, under the hill, it stays closed")
			var fl: Dictionary = ray(Vector3(20, 2.0, -22), Vector3(20, -5, -22))
			check(not fl.is_empty() and absf(fl["position"].y) < 0.1, "tunnel floor at the mouth is walkable (hit %s)" % fl.get("position", "nothing"))
			var found: Node = null
			for child in building.get_children(true):
				if child.name == "Foundation": found = child
			check(found != null, "building on a slope stands on a foundation")
			var fd: Dictionary = ray(Vector3(212, -1.0, -202), Vector3(203, -1.0, -202))
			check(not fd.is_empty(), "the foundation is solid (hit %s)" % fd.get("position", "nothing"))
			main.player._safe_spot = Vector3.INF
		200:
			check(main.player._safe_spot != Vector3.INF, "the player remembers solid ground")
			main.player.global_position = Vector3(600, 5, 0) # past the edge of the map
		420:
			var p: Vector3 = main.player.global_position
			check(absf(p.x) < 520 and p.y > -10.0, "fell off the map: put back on solid ground (%s)" % p)
			print("FAILS: %d" % fails)
			return true
	return false
