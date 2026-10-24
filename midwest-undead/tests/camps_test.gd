extends SceneTree
## Queue A: drawn zones (entering toast, lookups), the police station camp from
## its marker, a built camp (placement rule, name from its zone, its parts),
## recruits picking a camp, stations and capacity per camp, posting a guard
## (it shoots), morning supplies per camp, the bulletin board, kills near the
## station bringing the trader, building anywhere, save
## and load, and taking a camp down.
const SaveGame := preload("res://core/save_game.gd")
var main: Node
var test_map: PackedScene
var f := 0
var fails := 0
var p: Node
var camp2
var survivor: Node
var post: Node
var plot: Node
var zed: Node
var entered: Array[String] = []
var saved := {}

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map_root: Node3D = load("res://world/map/map.tscn").instantiate()
	var markers := map_root.get_node("Markers")
	var camp := KitBaseCamp.new(); camp.name = "Station"; camp.position = Vector3(0, 0, 20)
	markers.add_child(camp); camp.owner = map_root
	for part in KitBaseCamp.PARTS:
		var spot := Marker3D.new(); spot.name = part; spot.position = KitBaseCamp.PARTS[part]
		camp.add_child(spot); spot.owner = map_root
	var zone := KitZone.new(); zone.name = "PineHollow"; zone.zone_name = "Pine Hollow"
	zone.curve = Curve3D.new()
	for c in [Vector3(80, 0, 80), Vector3(160, 0, 80), Vector3(160, 0, 160), Vector3(80, 0, 160)]:
		zone.curve.add_point(c)
	markers.add_child(zone); zone.owner = map_root
	var sp := KitSpawnPoint.new(); sp.name = "Dale"; sp.role = "survivor"; sp.person = "Dale Hutchins"
	sp.position = Vector3(-60, 0, -60)
	markers.add_child(sp); sp.owner = map_root
	test_map = PackedScene.new()
	test_map.pack(map_root)
	map_root.free()
	_start()

func _start() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	root.add_child(main)

func g(x: float, z: float) -> Vector3:
	return Vector3(x, main.terrain.data.get_height(Vector3(x, 0, z)), z)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 2:
		p = main.player
		p.health = 1e9
		p.set_physics_process(false)
		for q in main.zombies: q.set_physics_process(false); q.global_position = Vector3(-900, 0, 900)
		main.zones.zone_entered.connect(func(n: String) -> void: entered.append(n))
		survivor = main.survivors.survivors[0] if not main.survivors.survivors.is_empty() else null
	match f:
		10:
			var camps = main.camps
			check(camps.station.name == "Police Station" and camps.camps.size() == 1, "the police station is a camp from its marker")
			check(camps.station.logbook is StaticBody3D and camps.station.board != null and camps.station.crate != null, "...with its logbook, bulletin board and supply crate")
			check(camps.station.logbook.global_position.distance_to(g(1.5, 20) + Vector3(0, 0.9, 0)) < 1.0, "...where the marker put them")
			check(main.zones.zone_at(g(120, 120)) == "Pine Hollow" and main.zones.zone_at(g(0, 0)) == "", "a drawn zone: inside it's Pine Hollow, outside nothing")
			p.global_position = g(120, 120) + Vector3(0, 0.1, 0)
		50:
			check(entered == ["Pine Hollow"], "walking in says so (%s)" % [entered])
			check(main.camps.placement_problem(g(0, 70)) != "", "a camp 50 m from the station is too close: \"%s\"" % main.camps.placement_problem(g(0, 70)))
			check(main.camps.placement_problem(g(120, 120)) == "", "...140 m away is fine")
			main.structures.build("camp_kit", Transform3D(Basis.IDENTITY, g(120, 120)), null)
			p.global_position = g(120, 112) + Vector3(0, 0.1, 0)
		120:
			var camps = main.camps
			check(camps.camps.size() == 2, "the built camp is a camp (%d)" % camps.camps.size())
			camp2 = camps.camps[1]
			check(camp2.name == "Pine Hollow Camp", "named after its zone (%s)" % camp2.name)
			check(camp2.logbook != null and camp2.board != null and camp2.crate != null, "...with its own logbook, board and crate")
			check(survivor != null, "a survivor to recruit")
			# Recruiting: two camps with room, so you'd pick; send them to the new one.
			check(camps.with_room().size() == 2, "two camps with room")
			main.survivors._send_to(survivor, camp2)
			p.global_position = g(300, 300) + Vector3(0, 0.1, 0) # out of sight: they get there
		160:
			check(survivor.state == survivor.State.HOME and survivor.camp_name == "Pine Hollow Camp", "they've moved in at Pine Hollow Camp")
			check(survivor.global_position.distance_to(camp2.center) < 6.0, "...standing round the camp (%.1f m)" % survivor.global_position.distance_to(camp2.center))
			# A garden plot and a guard post by the new camp; a plot by the station too.
			plot = main.structures.build("garden_plot", Transform3D(Basis.IDENTITY, g(128, 126)), null)
			post = main.structures.build("guard_post", Transform3D(Basis.IDENTITY, g(112, 128)), null)
			main.structures.build("garden_plot", Transform3D(Basis.IDENTITY, g(6, 26)), null)
		200:
			var camps = main.camps
			check(camps.free_station(camp2, "garden_plot") == plot and camps._stations(camps.station, "garden_plot").size() == 1, "each plot belongs to the camp it's near")
			check(camps.assign(survivor, "garden_plot") and camps.worked(camp2, "garden_plot") == 1, "they work the plot")
			check(camps.capacity(camp2) == 12 and camps.capacity(camps.station) == 10, "worked stations add room to their own camp (12 vs 10)")
			check(camps.free_posts(camp2).has(post), "the guard post belongs to the camp")
			camps.post_guard(survivor, post)
			zed = main._add_zombie(g(112, 148) + Vector3(0, 0.1, 0), null, "walker")
			zed.set_physics_process(false)
		201:
			check(not survivor.visible and camps_guard() != null, "posted: they're up on the post with a rifle")
			check(main.camps.worked(camp2, "garden_plot") == 0, "...and off the plot")
		500: # 5 s for the guard to shoot
			var hit: bool = not is_instance_valid(zed) or zed.is_dead or zed.health < zed.max_health
			check(hit, "the guard shoots a zombie 20 m from the post")
			main.camps.stand_down(survivor)
		502:
			check(survivor.visible and camps_guard() == null and survivor.global_position.distance_to(camp2.center) < 6.0, "stood down: back at camp")
			main.camps.assign(survivor, "garden_plot")
			main.day_night.day += 1
			main.day_night.hour = 8.0
		570:
			var food: int = camp2.crate.inventory.count("canned_food")
			check(food == 2 and main.camps.station.crate.inventory.count("canned_food") == 0, "the morning's food goes in that camp's crate (%d)" % food)
			check(camp2.board.summary == "Members 1 / 12" and "Dale Hutchins (on the garden)" in camp2.board.details, "the bulletin board: %s, %s" % [camp2.board.summary, camp2.board.details])
			# Kills near the station.
			p.global_position = g(0, 30) + Vector3(0, 0.1, 0)
			var near = main._add_zombie(g(0, 45) + Vector3(0, 0.1, 0), null, "walker")
			near.set_physics_process(false)
			near.take_hit(500.0, p.global_position, 1.0, p)
			var far = main._add_zombie(g(250, 250) + Vector3(0, 0.1, 0), null, "walker")
			far.set_physics_process(false)
			far.take_hit(500.0, far.global_position + Vector3(0, 0, 2), 1.0, p)
			check(main.camps.kills_near("Police Station") == 1, "a kill near the station counts; one far off doesn't (%d)" % main.camps.kills_near("Police Station"))
			main.camps.kills["Police Station"] = 74
			var last = main._add_zombie(g(5, 45) + Vector3(0, 0.1, 0), null, "walker")
			last.set_physics_process(false)
			last.take_hit(500.0, p.global_position, 1.0, p)
		610:
			check(main.trader_arrival.cleared, "75 kills near the station: word gets around (the trader's coming)")
			# Building anywhere: a fence out on its own (no zone, nobody's cleared it).
			var none: Array[RID] = []
			var view: Dictionary = main.structures.preview("fence", g(-200, -200) + Vector3(0, 1.6, 0), Vector3(0, -0.6, -1).normalized(), g(-200, -200), none)
			check(view["ok"], "a fence can go anywhere now (%s)" % view["text"])
			# The map screen draws with zones on.
			main.map_menu.open(); main.map_menu.show_zones = true; main.map_menu._redraw()
		612:
			main.map_menu.close()
			saved["food"] = camp2.crate.inventory.count("canned_food")
			main.save_game(SaveGame.new_path())
			SaveGame.pending_load = SaveGame.read(SaveGame.latest())
			root.remove_child(main); main.free()
			_start()
		640:
			p = main.player; p.set_physics_process(false)
			var camps = main.camps
			check(camps.camps.size() == 2 and camps.camps[1].name == "Pine Hollow Camp", "loaded: both camps, names kept")
			camp2 = camps.camps[1]
			survivor = main.survivors.survivors[0]
			check(survivor.camp_name == "Pine Hollow Camp" and survivor.working, "loaded: they still live there and work the plot")
			check(camp2.crate.inventory.count("canned_food") == saved["food"] and camps.kills_near("Police Station") == 75, "loaded: the crate and the kill count")
			# Taking the camp down: they move to the station; you get the kit back.
			camps.move_to(survivor, camps.station)
			camp2.piece.interact(p) # (nobody left there: it comes straight down)
		700:
			check(main.camps.camps.size() == 1 and survivor.camp_name == "Police Station", "taken down: one camp left, they moved to the station (%d camps, %s)" % [main.camps.camps.size(), survivor.camp_name])
			check(main.player.inventory.count("camp_kit") == 1, "...and the camp kit's back in your pack")
			print("FAILS: %d" % fails)
			return true
	return false

func camps_guard() -> Node:
	for n in main.get_children():
		if n.has_meta("survivor"):
			return n
	return null
