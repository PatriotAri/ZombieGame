extends SceneTree
## Quests P1: the game event bus, quest markers (point / area / usable), people
## by id. The map gets a few test markers and a place added before main loads it.
const GameEvents := preload("res://core/game_events.gd")
const Place := preload("res://world/markers/place.gd")
const HumanNPCScene := preload("res://characters/npcs/human_npc.tscn")
const SurvivorData := preload("res://characters/npcs/survivor_data.gd")
const SaveIO := preload("res://world/save_io.gd")
var main: Node
var p: Node
var f := 0
var fails := 0
var events: Array = [] # [name, data]
var npc: Node
var start := Vector3.ZERO

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	var map: Node3D = load("res://world/map/map.tscn").instantiate()
	var spot: Vector3 = Vector3.ZERO
	for n in map.find_children("*", "Marker3D", true, false):
		if n.get("role") == "player":
			spot = n.position
	var group := Node3D.new(); group.name = "QuestMarkers"; map.add_child(group); group.owner = map
	add_marker(map, group, "far_area", "area", spot + Vector3(60, 0, 0))
	add_marker(map, group, "start_area", "area", spot)
	add_marker(map, group, "radio", "usable", spot + Vector3(0, 1.4, -1.5))
	add_marker(map, group, "", "point", spot + Vector3(5, 0, 0)) # no id: a warning, skipped
	add_marker(map, group, "radio", "point", spot + Vector3(6, 0, 0)) # repeated: a warning, skipped
	var place := Place.new(); place.name = "TestPlace"; place.place_name = "Test Farm"; place.radius = 10.0
	place.position = spot + Vector3(-60, 0, 0); group.add_child(place); place.owner = map
	var packed := PackedScene.new()
	packed.pack(map)
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = packed
	root.add_child(main)

func add_marker(map: Node, group: Node, id: String, kind: String, at: Vector3) -> void:
	var m := KitQuestMarker.new()
	m.name = "M_" + (id if id != "" else "blank") + "_" + kind
	m.marker_id = id; m.kind = kind; m.radius = 8.0; m.prompt = "use the radio"
	m.position = at
	group.add_child(m); m.owner = map

func got(name: StringName) -> Array:
	return events.filter(func(e): return e[0] == name)

func _process(_d: float) -> bool:
	f += 1
	match f:
		3:
			p = main.player
			start = p.global_position
			for z in main.zombies: z.set_physics_process(false); z.global_position += Vector3(0, 0, 900)
			main.game_events.happened.connect(func(e, d): events.append([e, d]))
			var qw = main.quest_world
			print("--- markers")
			check(qw.marker("radio") != null and qw.marker("radio").kind == "usable", "found by id (the first \"radio\", the usable one)")
			check(qw.marker_ids().size() == 3, "blank and repeated ids skipped: %s" % [qw.marker_ids()])
			check(qw.marker("nope") == null, "unknown id: null")
		12:
			var qw = main.quest_world
			check(qw.is_inside("start_area") and got(&"area_entered").is_empty(), "starting inside an area: noted, but not 'entered'")
			p.global_position = qw.marker("far_area").global_position + Vector3(0, 1, 0)
		24:
			var qw = main.quest_world
			check(got(&"area_entered").map(func(e): return e[1]["marker"]) == ["far_area"], "walked into far_area: area_entered %s" % [got(&"area_entered")])
			check(got(&"area_left").map(func(e): return e[1]["marker"]) == ["start_area"], "and left start_area: area_left %s" % [got(&"area_left")])
			p.global_position = qw.marker("far_area").global_position + Vector3(0, 30, 0)
		36:
			check(got(&"area_left").size() == 2, "30 m above it: out of the area (height counts)")
			p.global_position = start
			p.velocity = Vector3.ZERO
		48:
			print("--- usable")
			var radio = main.quest_world.marker("radio")
			check(radio.interact_prompt() == "", "a usable marker no quest wants: no prompt")
			radio.interact(p)
			check(got(&"object_used").is_empty(), "...and using it does nothing")
			main.quest_world.set_usable("radio", true)
			check(radio.interact_prompt() == "use the radio", "wanted: it offers itself")
			# Aim at it: it's 1.5 m ahead (north) at head height.
			p.rotation.y = 0.0
			p.camera.rotation.x = 0.0
			p.global_position = Vector3(radio.global_position.x, start.y, radio.global_position.z + 1.5)
			p.velocity = Vector3.ZERO
		52:
			var looked = p._cast_look()
			print("    camera %s looking %s; radio at %s" % [p.camera.global_position, -p.camera.global_basis.z, main.quest_world.marker("radio").global_position])
			check(looked == main.quest_world.marker("radio"), "the look ray finds it (%s)" % [looked])
			p._interact()
			check(got(&"object_used").map(func(e): return e[1]["marker"]) == ["radio"], "interact: object_used radio")
			print("--- items")
			events.clear()
			p.give_item("bandage", 2)
			p.take_item("bandage", 5)
			p.give_item("bandage", 0)
			check(got(&"item_gained") == [[&"item_gained", {"item": "bandage", "amount": 2}]], "item_gained %s" % [got(&"item_gained")])
			check(got(&"item_lost") == [[&"item_lost", {"item": "bandage", "amount": 2}]], "item_lost: what actually left %s" % [got(&"item_lost")])
			p.take_item("bandage", 1)
			check(got(&"item_lost").size() == 1, "taking what you haven't got: nothing reported")
			print("--- kills and deaths")
			var z = main.zombies[0]
			z.global_position = p.global_position + Vector3(3, 0, 0)
			z.take_hit(9999.0, p.global_position, 0.0, p)
			var zk := got(&"zombie_killed")
			check(zk.size() == 1 and zk[0][1]["by_player"] == true and zk[0][1]["kind"] == z.kind, "zombie_killed by you %s" % [zk])
			var z2 = main.zombies[1]
			z2.die(false)
			check(got(&"zombie_killed").size() == 2 and got(&"zombie_killed")[1][1]["by_player"] == false, "one that falls off the map: not yours")
			npc = HumanNPCScene.instantiate()
			npc.npc_id = "test_person"
			npc.display_name = "Test Person"
			npc.player_can_hurt = true
			npc.position = p.global_position + Vector3(-4, 0, 0)
			main.add_child(npc)
		54:
			check(main.quest_world.npc("test_person") == npc, "a person by their id")
			npc.take_hit(30.0, p.global_position, 0.0, p)
			npc.take_damage(9999.0) # then a zombie finishes them
			var nd := got(&"npc_died")
			check(nd.size() == 1 and nd[0][1]["npc_id"] == "test_person" and nd[0][1]["by_player"] == false, "npc_died: the zombie's kill, not yours %s" % [nd])
			check(main.quest_world.npc("test_person") == npc and npc.is_dead, "still found by id once dead")
			var d := SurvivorData.new(); d.display_name = " Ann  Lee"
			check(d.npc_id() == "ann__lee", "a survivor with no id: from their name (%s)" % d.npc_id())
			var named := 0
			for s in DirAccess.get_files_at("res://characters/npcs/survivors/"):
				if s.ends_with(".tres") and load("res://characters/npcs/survivors/" + s).id != "": named += 1
			check(named == 5, "the five survivors have ids (%d)" % named)
			for scene in ["police_chief", "shopkeeper", "wagon_trader", "woodworker"]:
				var n = load("res://characters/npcs/%s.tscn" % scene).instantiate()
				check(n.npc_id != "", "%s.tscn: npc_id \"%s\"" % [scene, n.npc_id])
				n.free()
			print("--- clock, places, muting")
			main.day_night.hour = 8.9995
		60:
			var hp := got(&"hour_passed")
			check(hp.size() == 1 and hp[0][1]["hour"] == 9 and hp[0][1]["day"] == main.day_night.day, "hour_passed at 9:00 %s" % [hp])
			p.global_position = main.quest_world.marker("far_area").global_position + Vector3(-120, 1, 0)
		75:
			check(got(&"place_discovered").map(func(e): return e[1]["place"]) == ["Test Farm"], "place_discovered %s" % [got(&"place_discovered")])
			events.clear()
			main.game_events.muted = true
			p.give_item("bandage")
			GameEvents.send(&"anything")
			main.game_events.muted = false
			check(events.is_empty(), "muted (loading a save): nothing reported")
			# A save loaded where you stand inside an area: you didn't just arrive.
			p.global_position = main.quest_world.marker("far_area").global_position + Vector3(0, 1, 0)
			main._apply_save(load_data())
		90:
			check(got(&"area_entered").is_empty() and main.quest_world.is_inside("far_area"), "after a load: in the area, but no 'entered' %s" % [got(&"area_entered")])
			print("FAILS: %d" % fails)
			quit()
	return false

func load_data() -> Dictionary:
	var data: Dictionary = SaveIO.collect(main)
	data = JSON.parse_string(JSON.stringify(data)) # as it comes back from a file
	data["player"]["position"] = [p.global_position.x, p.global_position.y, p.global_position.z]
	return data
