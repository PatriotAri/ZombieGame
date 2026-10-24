extends SceneTree
## Quests phase 3: conversations (a reply shown only while its When holds, a
## reply's actions, a node that starts the conversation while its Start When
## holds), the journal's note on where a quest's got to, the tracked quest's
## objectives on the map screen, and things handling their own interact (the
## logbook, a door, planks, something you built, a trader's trading). On a test
## map with the station camp, a shop, the Quartermaster and a quest marker.
const TestMap := preload("res://tests/support/test_map.gd")
var main: Node
var q: Node
var p: Node
var f := 0
var fails := 0
var door_was := false

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	var map := TestMap.begin()
	TestMap.base_camp(map, Vector3(0, 0, 20))
	TestMap.building(map, "Shop", Vector3(40, 0, 40))
	TestMap.quest_marker(map, "farm", "area", Vector3(60, 0, -60)).radius = 10.0
	var m := KitPersonMarker.new()
	m.name = "Quartermaster"; m.person = load("res://characters/npcs/people/quartermaster.tres"); m.position = Vector3(5, 0.1, 5)
	TestMap.add(map, "People", m)
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = TestMap.finish(map)
	root.add_child(main)

func flag(name: String, at_least := 1) -> ConditionFlag:
	var c := ConditionFlag.new(); c.flag = name; c.at_least = at_least
	return c

## Hello -> [Ask about the farm (only once "met" is set) -> sets "asked", gives a plank] [Bye].
## Once "asked" is set, it starts at "again" instead.
func talk() -> QuestDialogue:
	var d := QuestDialogue.new()
	var hello := QuestDialogueNode.new(); hello.id = "start"; hello.lines.assign(["Hello."])
	var ask := QuestReply.new(); ask.text = "About the farm"; ask.when.assign([flag("met")])
	var set := ActionSetFlag.new(); set.flag = "asked"
	var give := ActionGive.new(); give.items = {"planks": 1}
	ask.actions.assign([set, give])
	var bye := QuestReply.new(); bye.text = "Bye"
	hello.replies.assign([ask, bye])
	var again := QuestDialogueNode.new(); again.id = "again"; again.lines.assign(["Asked already."])
	again.start_when.assign([flag("asked")])
	d.nodes.assign([hello, again])
	return d

func choices() -> Array:
	return main.choice_menu._list.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion()).map(func(b): return b.text)

func pick(text: String) -> void:
	for b in main.choice_menu._list.get_children():
		if b is Button and b.text == text and not b.is_queued_for_deletion():
			b.pressed.emit()
			return

func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		3:
			q = main.quests
			p = main.player
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			print("--- conversations")
			q.play(talk(), "quartermaster")
			main.dialogue._finish()
			check(choices() == ["Bye"], "a reply whose When doesn't hold isn't offered %s" % [choices()])
			pick("Bye")
			q.set_flag("met", 1)
		6:
			q.play(talk(), "quartermaster")
			main.dialogue._finish()
			check(choices() == ["About the farm", "Bye"], "once it holds, it is %s" % [choices()])
			var planks: int = p.inventory.count("planks")
			pick("About the farm")
			check(q.flag("asked") == 1 and p.inventory.count("planks") == planks + 1, "picked: its actions (a flag set, a plank given)")
		9:
			q.play(talk(), "quartermaster")
			check(main.dialogue.is_open() and main.dialogue._lines == (["Asked already."] as Array[String]),
					"next time it starts at the node whose Start When holds")
			main.dialogue._finish()
			print("--- journal and map")
			var quest := Quest.new(); quest.id = "test_farm"; quest.title = "The farm"
			var go := ObjectiveGoTo.new(); go.marker = "farm"; go.text = "Get to the farm"
			var stage := QuestStage.new(); stage.id = "go"; stage.journal_note = "Smoke over the farm."; stage.objectives.assign([go])
			quest.stages.assign([stage])
			q.add_quest(quest)
			var entry: Array = q.journal().filter(func(e): return e["id"] == "test_farm")
			check(entry.size() == 1 and entry[0]["note"] == "Smoke over the farm.", "the journal has the stage's note")
			check(q.tracked == "test_farm" and q.objective_places().size() == 1 and q.objective_places()[0]["label"] == "Get to the farm",
					"the tracked objective's place goes to the map")
			main.map_menu.open()
		14:
			check(main.map_menu.visible, "the map screen draws it (no errors)")
			main.map_menu.close()
			print("--- interaction")
			var logbook: Node = main.camps.station.logbook
			logbook.interact(p)
			check(main.save_menu.visible, "the logbook opens the save menu")
			main.save_menu.close()
			var door: Node = main.doors.filter(func(d: Node) -> bool: return String(d.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/Shop")))[0]
			door_was = door.is_open
			main._on_object_interacted(door)
		50:
			var door: Node = main.doors.filter(func(d: Node) -> bool: return String(d.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/Shop")))[0]
			check(door.is_open != door_was, "a door: interact swings it (open %s -> %s)" % [door_was, door.is_open])
			# Planks over a window: interact takes them down, the planks back.
			var idx := -1
			for i in main.fortifications.openings.size():
				if main.fortifications.openings[i]["kind"] == "window":
					idx = i
					break
			main.fortifications.board(idx, true)
			var planks_on: Node = main.fortifications.openings[idx]["planks"]
			var before: int = p.inventory.count("used_planks")
			main._on_object_interacted(planks_on)
			check(main.fortifications.openings[idx]["planks"] == null and p.inventory.count("used_planks") == before + 1,
					"planks: taken down, back in your pack as used planks")
			# Something you built: a fence, taken down for its materials.
			var fence: Node = main.structures.build("fence", Transform3D(Basis.IDENTITY, Vector3(-20, 0, 30)), null, true)
			var had: Dictionary = p.inventory.to_dict()
			main._on_object_interacted(fence)
			var gained := 0
			var now: Dictionary = p.inventory.to_dict()
			for id in now:
				gained += maxi(int(now[id]) - int(had.get(id, 0)), 0)
			check(gained > 0, "a fence: taken down, its materials back (%d items)" % gained)
			var qm: Node = q.npc("quartermaster")
			var own: Array = qm.own_business(main)
			check(own.size() == 2 and own[0] == "Trade", "the Quartermaster's own business: Trade")
			own[1].call()
			check(main.shop_menu.visible, "...which opens the shop")
			main.shop_menu.close()
			print("FAILS: %d" % fails)
			return true
	return false
