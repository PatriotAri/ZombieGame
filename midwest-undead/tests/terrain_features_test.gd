extends SceneTree
## Phase 3 on test-only terrain: roads (level, cut/fill, paint, spans), creeks
## (bed downhill, water lookup, carving, falls), ponds (water lookup, deep
## water left out of the navigation).
const Road := preload("res://world/map/road.gd")
const RoadSpan := preload("res://world/map/road_span.gd")
const Creek := preload("res://world/map/creek.gd")
const CreekFalls := preload("res://world/map/creek_falls.gd")
const Pond := preload("res://world/map/pond.gd")
const Water := preload("res://world/water.gd")
var main: Node
var t: Node
var f := 0
var fails := 0
var orig := {}
var road: Node
var bridge: Node
var creek: Node
var pond: Node

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func h(x: float, z: float) -> float:
	return t.data.get_height(Vector3(x, 0, z))

func _sculpt() -> void:
	var d = t.data
	for x in range(90, 260): # a hillside rising toward +z (about 22 degrees)
		for z in range(-200, -100):
			d.set_height(Vector3(x, 0, z), (z + 200) * 0.4)
	for x in range(300, 311): # a trench across x 300..310
		for z in range(-170, -130):
			d.set_height(Vector3(x, 0, z), -5.0)
	for x in range(390, 490): # a slope falling toward +x for the creek
		for z in range(-170, -130):
			d.set_height(Vector3(x, 0, z), (490 - x) * 0.1)
	for x in range(0, 31): # a pond basin
		for z in range(-300, -269):
			d.set_height(Vector3(x, 0, z), -3.0)
	d.update_maps(0, true, false)
	t.collision.build()
	orig = {"up": h(170, -145), "down": h(170, -158), "creek": h(420, -150)}

func _path(node: Path3D, points: Array) -> void:
	node.curve = Curve3D.new()
	for p: Vector3 in points:
		node.curve.add_point(p)

func _physics_process(_d: float) -> bool:
	f += 1
	main.player.health = main.player.max_health
	match f:
		60:
			t = main.terrain
			for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
			_sculpt()
			road = Road.new(); road.style = load("res://world/map/roads/paved_two_lane.tres")
			_path(road, [Vector3(110, 0, -150), Vector3(240, 0, -150)])
			main.town.add_child(road)
			bridge = Road.new(); bridge.style = load("res://world/map/roads/gravel_road.tres")
			_path(bridge, [Vector3(270, 0, -150), Vector3(340, 0, -150)])
			main.town.add_child(bridge)
			var span := RoadSpan.new(); span.length = 16.0
			bridge.add_child(span); span.global_position = Vector3(305, 0.0, -150)
			creek = Creek.new(); creek.width_start = 3.0; creek.width_end = 4.0; creek.depth = 0.6
			_path(creek, [Vector3(400, 0, -150), Vector3(480, 0, -150)])
			main.town.add_child(creek)
			var falls := CreekFalls.new(); falls.pool = 10.0
			creek.add_child(falls); falls.global_position = Vector3(440, 0, -150)
			pond = Pond.new(); pond.size = Vector2(40, 40)
			main.town.add_child(pond); pond.global_position = Vector3(15, -0.5, -285)
		62:
			var t0 := Time.get_ticks_msec()
			var rect: Rect2 = road.apply(t)
			print("    road apply: %d ms, area %s" % [Time.get_ticks_msec() - t0, rect])
			var c := h(170, -150)
			check(absf(h(170, -153) - c) < 0.05 and absf(h(170, -147) - c) < 0.05, "road level side to side (%.2f / %.2f / %.2f)" % [h(170, -153), c, h(170, -147)])
			check(h(170, -145) < orig["up"] - 0.5, "cut into the hill above (%.2f was %.2f)" % [h(170, -145), orig["up"]])
			check(h(170, -158) > orig["down"] + 0.5, "built up below (%.2f was %.2f)" % [h(170, -158), orig["down"]])
			check(t.data.get_control_base_id(Vector3(170, 0, -150)) == 5 and not t.data.get_control_auto(Vector3(170, 0, -150)), "painted under the road")
			bridge.apply(t)
			check(absf(h(305, -150) + 5.0) < 0.01, "ground under the bridge span left alone (%.2f)" % h(305, -150))
			var cb := Time.get_ticks_msec()
			creek.apply(t)
			print("    creek apply: %d ms" % (Time.get_ticks_msec() - cb))
			var bed: PackedFloat32Array = creek.bed
			var downhill := true
			for i in range(1, bed.size()):
				if bed[i] > bed[i - 1] + 0.001: downhill = false
			check(downhill and bed.size() > 70, "creek bed only ever runs downhill (%d samples)" % bed.size())
			check(h(420, -150) < orig["creek"] - 0.3, "channel carved (%.2f was %.2f)" % [h(420, -150), orig["creek"]])
			check(t.data.get_control_base_id(Vector3(420, 0, -150)) == 9, "creek stones painted")
			var first_bed: PackedFloat32Array = creek.bed.duplicate()
			var ground_once := h(420, -150)
			creek.apply(t)
			var drift := 0.0
			for i in first_bed.size(): drift = maxf(drift, absf(first_bed[i] - creek.bed[i]))
			check(drift < 0.02 and absf(h(420, -150) - ground_once) < 0.02, "applying again doesn't dig deeper (bed moved %.3f m)" % drift)
		70:
			print("    bed[19..21] %s ground 419..421: %.2f %.2f %.2f" % [creek.bed.slice(19, 22), h(419, -150), h(420, -150), h(421, -150)])
			var s: float = creek.surface_at(Vector3(420, 0, -150))
			check(not is_nan(s) and absf(s - (h(420, -150) + creek.depth)) < 0.15, "water surface over the creek (%.2f, ground %.2f)" % [s, h(420, -150)])
			check(is_nan(creek.surface_at(Vector3(420, 0, -140))), "no water 10 m to the side")
			var drop: float = creek.surface_at(Vector3(437, 0, -150)) - creek.surface_at(Vector3(443, 0, -150))
			check(drop > 0.5, "waterfall: water drops %.2f m at the falls" % drop)
			check(absf(creek.surface_at(Vector3(431, 0, -150)) - creek.surface_at(Vector3(438, 0, -150))) < 0.05, "level pool above the falls")
			var built: Node = road.get_node_or_null("Built")
			check(built != null and built.find_children("*", "MeshInstance3D", true, false).size() >= 3, "road surface and markings made")
			var space = main.get_world_3d().direct_space_state
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(305, 10, -150), Vector3(305, -10, -150)))
			check(not hit.is_empty() and absf(hit["position"].y - 0.04) < 0.1, "bridge deck has collision (hit at %s)" % (hit.get("position", "nothing")))
			check(absf(pond.surface_at(Vector3(15, 0, -285)) + 0.5) < 0.01, "pond surface in the basin")
			check(is_nan(pond.surface_at(Vector3(33, 0, -285))), "no pond water on dry land inside its rectangle")
			check(absf(Water.depth_at(self, Vector3(15, -3, -285)) - 2.5) < 0.01, "Water.depth_at 2.5 m in the pond")
			main.nav_region._terrain_faces.clear()
			main.nav_region.rebake_all()
		400:
			var m: RID = main.get_world_3d().navigation_map
			var deep := NavigationServer3D.map_get_closest_point(m, Vector3(15, -3, -285))
			check(Vector2(deep.x - 15, deep.z + 285).length() > 3.0, "zombies can't walk in the deep pond (nearest walkable %s)" % deep)
			var shallow := NavigationServer3D.map_get_closest_point(m, Vector3(420, h(420, -150), -150))
			check(Vector2(shallow.x - 420, shallow.z + 150).length() < 1.0, "the shallow creek is walkable (%s)" % shallow)
			print("FAILS: %d" % fails)
			return true
	return false
