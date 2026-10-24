extends SceneTree
## The main story (quests/main/westside_safe_house.tres) played through on a
## test map with every marker and person it needs (the list in HOW_TO_MAP.md,
## section 12): the Chief's briefing; the safe house (a noise, an autosave
## asked for); reporting back (paid); 75 kills round the station; the wagon and
## the trader turning up once you're away; finding them; untying the woodworker
## at the bandit camp (his lines, then free: saved through a load); him moving
## home once you're away; finding him there; the Chief's afterword. Then the
## other way: having been to the safe house before the briefing, the Chief skips
## ahead (and pays then).
const TestMap := preload("res://tests/support/test_map.gd")
const SaveGame := preload("res://core/save_game.gd")
const STORY := "westside_safe_house"
var main: Node
var test_map: PackedScene
var q: Node
var p: Node
var f := 0
var fails := 0
var step := 0
var wait_from := 0
var money := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map := TestMap.begin()
	TestMap.base_camp(map, Vector3(0, 0, 20))
	TestMap.person(map, "chief", Vector3(3, 0.1, 22))
	TestMap.person(map, "quartermaster", Vector3(-3, 0.1, 22))
	TestMap.person(map, "woodworker", Vector3(0, 0.1, -200), true)
	TestMap.quest_marker(map, "station", "area", Vector3(0, 0, 20)).radius = 75.0
	TestMap.quest_marker(map, "safe_house", "area", Vector3(-200, 0, 60)).radius = 15.0
	TestMap.quest_marker(map, "wagon", "point", Vector3(12, 0, 34))
	TestMap.quest_marker(map, "wagon_trader", "point", Vector3(9, 0.1, 34))
	TestMap.quest_marker(map, "bandit_camp", "area", Vector3(0, 0, -200)).radius = 20.0
	TestMap.quest_marker(map, "woodworker_home", "point", Vector3(-8, 0.1, 30))
	TestMap.quest_marker(map, "gas_station", "area", Vector3(-200, 0, 90)).radius = 15.0
	test_map = TestMap.finish(map)
	_start()

func _start() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	main.extra_zombies = 0
	root.add_child(main)

func at_stage() -> String:
	return q._state[STORY]["stage"] if q._state.has(STORY) else ""

func go(where: Vector3) -> void:
	p.global_position = where + Vector3(0, 0.5, 0)
	p.velocity = Vector3.ZERO

func marker(id: String) -> Vector3:
	return q.world.marker(id).global_position

## Talks to someone the way pressing interact does, and clicks through what they say.
func talk_to(id: String) -> void:
	main._on_npc_interacted(q.npc(id))
	for i in 12:
		if main.dialogue.is_open():
			main.dialogue._finish()
		elif main.choice_menu.visible:
			main.choice_menu._list.get_child(0).pressed.emit()

## Waits (returns false) until cond holds or 300 frames go by (then it's a failure).
func waited(cond: bool, what: String) -> bool:
	if cond:
		check(true, what)
		wait_from = f
		step += 1
		return true
	if f - wait_from > 300:
		check(false, what + " (gave up: stage \"%s\")" % at_stage())
		wait_from = f
		step += 1
		return true
	return false

func _physics_process(_d: float) -> bool:
	f += 1
	if f < 3:
		return false
	if main.player:
		main.player.health = main.player.max_health
	match step:
		0:
			q = main.quests
			p = main.player
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			check(q.status_of(STORY) == "active" and at_stage() == "talk_chief", "the story starts by itself: talk to the Chief")
			check(q.marked_people().get("chief") == "?", "a ? over the Chief")
			go(Vector3(0, 0, 24))
			talk_to("chief")
			wait_from = f
			step += 1
		1:
			if waited(at_stage() == "reach_safe_house", "briefed: on to the safe house"):
				check(q.objective_places().size() == 1 and q.objective_places()[0]["label"] == "Safe house", "the map shows the safe house")
				var options: Array = q.talk_options(q.npc("chief"))
				check(options.size() == 1, "the Chief has a reminder meanwhile")
				go(marker("safe_house"))
		2:
			if waited(at_stage() == "report", "at the safe house: back to report"):
				go(Vector3(0, 0, 24))
				money = p.money
				talk_to("chief")
		3:
			if waited(at_stage() == "clear_zone", "reported: on to clearing the station"):
				check(FileAccess.file_exists(SaveGame.autosave_path()), "it autosaved at the safe house (nothing was after you)")
				check(p.money == money + 100, "paid $100 ($%d)" % (p.money - money))
				for i in 75:
					var z = main._add_zombie(Vector3(20, 0.1, 20 + i * 0.2), null, "walker")
					z.set_physics_process(false)
					z.take_hit(9999.0, p.global_position, 0.0, p)
		4:
			if waited(at_stage() == "wait_for_trader", "75 kills round the station: the station's quieter"):
				check(q.npc("wagon_trader") == null, "you're right there: no trader yet")
				go(Vector3(300, 0, 300))
		5:
			if waited(q.npc("wagon_trader") != null and main.get_node_or_null("Quest_wagon") != null, "you went off: the wagon and the trader turned up"):
				go(marker("wagon_trader") + Vector3(3, 0, 0))
		6:
			if waited(at_stage() == "rescue_woodworker", "found the trader: on to the woodworker"):
				var ww: HumanNPC = q.npc("woodworker")
				check(ww.captive and ww.interact_prompt() == "untie Woodworker" and not main.camps.woodworker_free(), "he's tied up at the bandit camp")
				go(ww.global_position + Vector3(2, 0, 0))
				main._on_npc_interacted(ww)
				check(main.dialogue.is_open() and main.dialogue._lines[0].begins_with("Easy"), "untying him: his lines")
				for i in 3:
					main.dialogue._finish()
		7:
			if waited(at_stage() == "meet_woodworker", "untied: on to meeting him at the station"):
				check(not q.npc("woodworker").captive and main.camps.woodworker_free(), "he's free (and counts at the station)")
				check(q.npc("woodworker").global_position.distance_to(marker("bandit_camp")) < 25.0, "you're still at the camp: he hasn't moved yet")
				# Save, load: he's still free.
				main.save_game(SaveGame.new_path())
				SaveGame.pending_load = SaveGame.read(SaveGame.latest())
				root.remove_child(main); main.free()
				_start()
		8:
			if f - wait_from == 10:
				q = main.quests
				p = main.player
				for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
				check(at_stage() == "meet_woodworker" and not q.npc("woodworker").captive, "loaded: still free, still to meet him")
				go(Vector3(300, 0, -300))
				step += 1
		9:
			if waited(q.npc("woodworker").global_position.distance_to(marker("woodworker_home")) < 1.0, "you went off: he's moved home"):
				go(marker("woodworker_home") + Vector3(3, 0, 0))
		10:
			if waited(q.status_of(STORY) == "done", "found him at home: the story's done"):
				var own: Array = q.npc("woodworker").own_business(main)
				check(own.size() == 2 and own[0] == "Build something", "he builds for you now")
				main._on_npc_interacted(q.npc("chief"))
				check(main.dialogue.is_open() and main.dialogue._lines[0].begins_with("A trader in our own yard"), "the Chief's afterword")
				main.dialogue._finish()
				# The other way round: the safe house first.
				root.remove_child(main); main.free()
				_start()
				wait_from = f
		11:
			if f - wait_from == 10:
				q = main.quests
				p = main.player
				for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
				go(marker("safe_house"))
				step += 1
		12:
			if f - wait_from == 40:
				go(Vector3(0, 0, 24))
				money = p.money
				talk_to("chief")
				step += 1
		13:
			if waited(at_stage() == "clear_zone", "the safe house first: the Chief skips ahead to clearing the station"):
				check(p.money == money + 100, "...and pays then ($%d)" % (p.money - money))
				# The example side quest: the Quartermaster's medicine run.
				q.add_quest(load("res://quests/examples/medicine_run.tres"))
				check(q.status_of("medicine_run") == "available" and q.marked_people().get("quartermaster") == "!", "medicine run: on offer, a ! over the Quartermaster")
				main._on_npc_interacted(q.npc("quartermaster"))
				var picked := false
				for i in 12: # pick it, hear it out, ask what's in it, then Deal
					if main.dialogue.is_open():
						main.dialogue._finish()
					elif main.choice_menu.visible:
						var wanted: Array = ["Medicine Run  (new)", "What's in it for me?", "Deal."]
						for b in main.choice_menu._list.get_children():
							if b is Button and b.text in wanted and not b.is_queued_for_deletion():
								picked = true
								b.pressed.emit()
								break
				check(picked and q.status_of("medicine_run") == "active", "taken (after asking what's in it)")
				go(marker("gas_station"))
		14:
			if waited(q._state["medicine_run"]["stage"] == "bring_back", "at the gas station: bring it back"):
				go(Vector3(0, 0, 24))
				money = p.money
				talk_to("quartermaster")
		15:
			if waited(q.status_of("medicine_run") == "done", "brought back: done"):
				check(p.money == money + 60 and p.inventory.count("health_pack") >= 1, "paid $60 and a health pack")
				print("FAILS: %d" % fails)
				return true
	return false
