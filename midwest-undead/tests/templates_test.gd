extends SceneTree
## Building tools phase 5: every template and variant applies cleanly;
## furnishing puts the right things (and loot) in rooms and leaves them
## reachable; applying again replaces only what was put in; the silo can be
## gone into and climbed to its roof.
const KitBuilding := preload("res://world/building.gd")
const TerrainEdit := preload("res://world/map/terrain_edit.gd")
var main: Node
var f := 0
var fails := 0
var checked: Array = [] # buildings whose rooms get the reachability check
var silo: Node3D
var baked_at := -1
var climb_from := -1
var highest := 0.0
var base := Vector3(-150, 0, -120)

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	main = load("res://world/main.tscn").instantiate()
	root.add_child(main)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, TerrainEdit.height_at(main.terrain, at), at.z)

func make(template: String, variant: int, at: Vector3) -> Node3D:
	var b: Node3D = KitBuilding.new()
	b.position = ground(at)
	b.template = template
	b.template_variant = variant
	b.apply_template()
	main.nav_region.add_child(b)
	return b

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
		main.player.set_physics_process(false)
		# Every template, off on its own (no bake needed): warnings, furnishing.
		var bad := []
		var empty := []
		for t: String in KitTemplates.NAMES:
			for v in 3:
				var b: Node3D = KitBuilding.new()
				b.template = t
				b.template_variant = v
				b.apply_template()
				root.add_child(b)
				b.position = Vector3(3000, 0, 3000)
				var w: PackedStringArray = b._get_configuration_warnings()
				if not w.is_empty():
					bad.append("%s %d: %s" % [t, v, w])
				var kinds: Array = b.rooms.filter(func(r): return r.kind != "None")
				var added: Array = b.furnish_rooms()
				if not kinds.is_empty() and added.is_empty():
					empty.append("%s %d" % [t, v])
				b.queue_free()
		check(bad.is_empty(), "all 36 templates apply with no warnings %s" % [bad])
		check(empty.is_empty(), "...and furnish (%s)" % [empty])
		# Reapplying: the old extras and furniture go.
		var gas := make("Gas station", 0, base + Vector3(0, 0, 60))
		gas.furnish_rooms()
		check(gas.get_children().any(func(n): return n.name.begins_with("Canopy")), "a gas station's canopy")
		var mine := Node3D.new(); mine.name = "Mine"; gas.add_child(mine)
		var count: int = gas.get_children().filter(func(n): return n.has_meta("furnished")).size()
		gas.furnish_rooms()
		check(gas.get_children().filter(func(n): return n.has_meta("furnished")).size() == count and gas.get_node_or_null("Mine") != null,
				"furnishing again replaces its own pieces (%d) and nothing else" % count)
		gas.template = "Church"; gas.template_variant = 1
		gas.apply_template()
		var names: Array = gas.get_children().map(func(n): return str(n.name))
		check(not names.any(func(n): return n.begins_with("Canopy") or n.begins_with("StoreFloor")) and gas.get_node_or_null("Mine") != null,
				"a new template: the old canopy and furniture go, yours stays")
		check(gas.get_children().any(func(n): return n is KitSteeple) and gas.get_children().any(func(n): return n is KitSign and n.text == "CHURCH"),
				"...the church's steeple and sign")
		gas.queue_free()
		# Three to walk round: a farmhouse (upstairs too), a ranch, a big school.
		checked = [make("Farmhouse", 0, base), make("Ranch house", 0, base + Vector3(30, 0, 0)), make("School", 2, base + Vector3(0, 0, -40))]
		for b: Node3D in checked:
			b.furnish_rooms()
		var fh: Node3D = checked[0]
		var fridge = fh.get_children().filter(func(n): return n.name == "KitchenFridge")
		var dresser = fh.get_children().filter(func(n): return n.name.begins_with("BedroomDresser"))
		check(fridge.size() == 1 and fridge[0].loot_table == "kitchen", "the kitchen has a fridge with food in it")
		check(dresser.size() >= 1 and dresser[0].loot_table == "bedroom", "a bedroom's dresser takes the bedroom's loot")
		check(fh.get_children().any(func(n): return n.name.begins_with("LivingRoomCouch")), "a couch in the living room")
		# The silo.
		silo = KitSilo.new()
		silo.position = ground(base + Vector3(30, 0, 40))
		main.nav_region.add_child(silo)
		main.nav_region.bake_finished.connect(func() -> void: baked_at = f, CONNECT_ONE_SHOT)
		main.fortifications.rebake()
	if f == 6:
		var door: Node = silo.get_node_or_null("Door")
		check(door != null and door.can_be_bashed(), "the silo has a door")
		var space := root.get_world_3d().direct_space_state
		var top: Vector3 = silo.global_position + Vector3(0, silo.height + silo.dome + 3.0, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top + Vector3(-1.0, 0, 0), top + Vector3(-1.0, -30, 0)))
		check(not hit.is_empty() and hit["position"].y > silo.global_position.y + silo.height, "a domed roof")
		var la: float = silo._angle(KitSilo.SEGMENTS / 2)
		var hatch: Vector3 = silo.global_position + Vector3(cos(la), 0, sin(la)) * (silo.radius - 0.4)
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(hatch + Vector3(0, silo.height + 3.0, 0), hatch - Vector3(0, 1, 0)))
		check(not down.is_empty() and down["position"].y < silo.global_position.y + 1.0, "an open hatch over the ladder")
		# The player climbs the ladder.
		door.set_open(true, false)
		var foot: Vector3 = silo.global_position + Vector3(cos(la), 0, sin(la)) * (silo.radius - 0.7) + Vector3(0, 0.5, 0)
		main.player.global_position = foot
		main.player.rotation.y = atan2(-cos(la), -sin(la)) # facing the ladder (-Z ahead)
		main.player.set_physics_process(true)
		Input.action_press("move_forward")
		climb_from = f
	if climb_from > 0 and f < climb_from + 600:
		highest = maxf(highest, main.player.global_position.y - silo.global_position.y)
	if climb_from > 0 and f == climb_from + 60 * 10:
		Input.action_release("move_forward")
		check(highest > silo.height, "climbed the ladder up through the hatch (%.1f m up; the wall's %.1f)" % [highest, silo.height])
		main.player.set_physics_process(false)
	if baked_at > 0 and f > baked_at + 90 and climb_from > 0 and f > climb_from + 600 and main.nav_region._dirty.is_empty() and main.nav_region._baking.is_empty():
		var map: RID = main.get_world_3d().navigation_map
		for b: Node3D in checked:
			var from: Vector3 = b.global_transform * Vector3(1.6, b.floor_y + 0.05, b.outside_front_door(0.0).distance_to(b.global_position) * 0.0)
			var door := b.to_local(b.outside_front_door(-1.6))
			from = b.global_transform * Vector3(door.x, b.floor_y + 0.05, door.z)
			var cut := []
			for r: KitRoom in b.rooms:
				var to: Vector3 = b.global_transform * Vector3(r.point.x, b.floor_top(r.level) + 0.05, r.point.y)
				var path := NavigationServer3D.map_get_path(map, from, to, true)
				var end: Vector3 = path[path.size() - 1] if path.size() else Vector3.INF
				if end.distance_to(to) > 1.6:
					cut.append("%s (%.1f m short)" % [r.kind, end.distance_to(to)])
			check(cut.is_empty(), "%s, furnished: every room can be walked to %s" % [b.template, cut])
		print("FAILS: %d" % fails)
		return true
	return f > 3000
