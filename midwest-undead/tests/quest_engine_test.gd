extends SceneTree
## The quest engine (quests/): quests made in code on a test map with three
## quest markers and the chief.
##   A main story quest that starts by itself: go to an area; talk to the chief
##   (a stage whose objective has the same id as the last stage's: not done
##   already); then collect, kill, use and an optional extra, all at once, a
##   stage reward paid once, a flag, and a branch to the end.
##   A side quest on offer from the chief once the story's done: accepted in
##   its offer conversation, then a delivery to him.
##   A side quest with a time limit that runs out: failed.
##   Saving partway through the third stage and loading: counts, flags and the
##   usable marker come back.
const TestMap := preload("res://tests/support/test_map.gd")
const SaveGame := preload("res://core/save_game.gd")
var main: Node
var test_map: PackedScene
var q: Node # the quest manager
var p: Node
var f := 0
var fails := 0
var events: Array = []
var money_before := 0
var saved_at := -1

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map := TestMap.begin()
	TestMap.quest_marker(map, "farm", "area", Vector3(60, 0, 0)).radius = 8.0
	TestMap.quest_marker(map, "radio", "usable", Vector3(0, 1.5, -1.5))
	TestMap.quest_marker(map, "well", "point", Vector3(-30, 0, 0))
	TestMap.spawn_point(map, "chief", Vector3(3, 0.1, 6))
	test_map = TestMap.finish(map)
	_start()

func _start() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	root.add_child(main)

# --- The quests -------------------------------------------------------------------

func objective(script: Script, props: Dictionary) -> QuestObjective:
	var o: QuestObjective = script.new()
	for k in props:
		o.set(k, props[k])
	return o

func stage(id: String, objectives: Array, props := {}) -> QuestStage:
	var s := QuestStage.new()
	s.id = id
	s.objectives.assign(objectives)
	for k in props:
		s.set(k, props[k])
	return s

func lines(text: String) -> QuestDialogue:
	return QuestDialogue.of([text] as Array[String])

func story() -> Quest:
	var quest := Quest.new()
	quest.id = "test_story"; quest.title = "Test story"
	var went := ActionSetFlag.new(); went.flag = "went"
	quest.stages.assign([
		stage("go", [objective(ObjectiveGoTo, {"id": "1", "marker": "farm", "text": "Get to the farm"})], {"on_complete": [went] as Array[QuestAction]}),
		stage("talk", [objective(ObjectiveTalkTo, {"id": "1", "npc": "chief", "dialogue": lines("You made it."), "text": "Talk to the chief"})]),
		stage("work", [
			objective(ObjectiveCollect, {"id": "scrap", "item": "scrap_metal", "count": 2, "text": "Scrap ({count}/{total})"}),
			objective(ObjectiveKill, {"id": "kills", "count": 2, "text": "Kill two ({count}/{total})"}),
			objective(ObjectiveUse, {"id": "radio", "marker": "radio", "text": "Use the radio"}),
			objective(ObjectiveEvent, {"id": "extra", "event": "place_discovered", "optional": true, "text": "Find somewhere"}),
		], {"reward_money": 5, "reward_items": {"planks": 1}, "next": "talk",
			"branches": [branch("went", "end")] as Array[QuestBranch]}),
	])
	return quest

func branch(flag_name: String, next: String) -> QuestBranch:
	var b := QuestBranch.new()
	var c := ConditionFlag.new(); c.flag = flag_name
	b.when.assign([c])
	b.next = next
	return b

func errand() -> Quest:
	var quest := Quest.new()
	quest.id = "test_errand"; quest.title = "Test errand"; quest.giver = "chief"
	var after := ConditionQuest.new(); after.quest = "test_story"; after.status = "done"
	quest.available_when.assign([after])
	var offer := QuestDialogue.new()
	var node := QuestDialogueNode.new(); node.lines.assign(["Bring me planks?"])
	var yes := QuestReply.new(); yes.text = "Sure"; yes.action = "accept"
	var no := QuestReply.new(); no.text = "No"; no.action = "decline"
	node.replies.assign([yes, no])
	offer.nodes.assign([node])
	quest.offer = offer
	quest.stages.assign([stage("bring", [objective(ObjectiveDeliver, {"npc": "chief", "item": "planks", "count": 1, "text": "Bring the chief a plank"})])])
	quest.reward_money = 20
	return quest

func timed() -> Quest:
	var quest := Quest.new()
	quest.id = "test_timed"; quest.title = "Test timed"; quest.time_limit_hours = 1.0
	quest.stages.assign([stage("wait", [objective(ObjectiveSurvive, {"hours": 3.0, "text": "Hold out"})])])
	return quest

# --- Helpers ----------------------------------------------------------------------

func finish_talk() -> void:
	var guard := 0
	while main.dialogue.is_open() and guard < 10:
		main.dialogue._finish()
		guard += 1

func pick(text: String) -> bool:
	for b in main.choice_menu._list.get_children():
		if b is Button and b.text == text:
			b.pressed.emit()
			return true
	return false

func status(id: String) -> String:
	return q.status_of(id)

func at_stage(id: String) -> String:
	return q._state[id]["stage"]

# --- The test ---------------------------------------------------------------------

func _physics_process(_d: float) -> bool:
	f += 1
	if f >= 3 and main:
		main.player.health = main.player.max_health
	match f:
		3:
			q = main.quests
			p = main.player
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			main.game_events.happened.connect(func(e, d): events.append([e, d]))
			q.add_quest(story(), true)
			q.add_quest(errand())
			check(status("test_story") == "active" and at_stage("test_story") == "go", "the story starts by itself, at its first stage")
			check(status("test_errand") == "locked", "the errand isn't on offer yet (the story's not done)")
			check(q.objective_text() == "Get to the farm", "HUD: %s" % q.objective_text())
			check(q.objective_places().size() == 1 and q.objective_places()[0]["radius"] == 8.0, "the map gets the farm's area")
			p.global_position = main.quest_world.marker("farm").global_position + Vector3(0, 1, 0)
		30:
			check(at_stage("test_story") == "talk", "at the farm: on to the talk (and its objective \"1\" isn't done already)")
			check(q.flag("went") == 1, "the stage's action set a flag")
			check(q.marked_people().get("chief") == "?", "a ? over the chief")
			var options: Array = q.talk_options(main.chief)
			check(options.size() == 1, "the chief has the story to talk about")
			options[0][1].call()
			check(main.dialogue.is_open(), "...and says his line")
			finish_talk()
		55:
			check(at_stage("test_story") == "work", "talked: on to the work")
			check(q.world.marker("radio").usable, "the radio offers itself")
			money_before = p.money
			p.give_item("scrap_metal", 1)
			p.global_position = Vector3(10, 1, 10)
			for i in 1:
				main._add_zombie(p.global_position + Vector3(3, 0, 0), null, "walker").take_hit(9999.0, p.global_position, 0.0, p)
			check(q.objective_text().contains("Scrap (1/2)") and q.objective_text().contains("Kill two (1/2)"),
					"counting: %s" % q.objective_text().replace("\n", " | "))
			check(q.objective_text().contains("Find somewhere  (optional)"), "the extra shows as optional")
			# Save here, then load.
			main._save_game(SaveGame.new_path())
			SaveGame.pending_load = SaveGame.read(SaveGame.latest())
			root.remove_child(main); main.free()
			main = null
			_start()
		80:
			q = main.quests
			p = main.player
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			q.add_quest(story(), true) # (made in code: not in a file, so added again; the save puts its state back)
			q.add_quest(errand())
			q.load_state(SaveGame.read(SaveGame.latest())["quest"])
			q.end_load()
			main.game_events.happened.connect(func(e, d): events.append([e, d]))
			check(at_stage("test_story") == "work" and q.flag("went") == 1, "loaded: still on the work, the flag kept")
			check(q.objective_text().contains("Kill two (1/2)") and q.objective_text().contains("Scrap (1/2)"), "...with its counts %s" % q.objective_text().replace("\n", " | "))
			check(q.world.marker("radio").usable, "...and the radio offering itself again")
			money_before = p.money
			p.give_item("scrap_metal", 1)
			main._add_zombie(p.global_position + Vector3(3, 0, 0), null, "walker").take_hit(9999.0, p.global_position, 0.0, p)
			q.world.marker("radio").interact(p)
		110:
			check(status("test_story") == "done", "collected, killed and used (the extra skipped): the branch ends it (%s, %s)" % [status("test_story"), at_stage("test_story")])
			check(p.money == money_before + 5, "the stage's reward paid once ($%d more)" % (p.money - money_before))
			check(not q.world.marker("radio").usable, "the radio stops offering itself")
			check(events.any(func(e): return e[0] == &"quest_completed" and e[1]["quest"] == "test_story"), "quest_completed reported")
			var entry: Array = q.journal().filter(func(e): return e["id"] == "test_story")
			check(entry.size() == 1 and entry[0]["status"] == "done" and entry[0]["steps"].size() == 5,
					"the journal lists what was done (%s)" % [entry[0]["steps"].map(func(s): return s["objective"]) if entry.size() else []])
		130:
			check(status("test_errand") == "available" and q.marked_people().get("chief") == "!", "the errand's on offer: a ! over the chief")
			var options: Array = q.talk_options(main.chief)
			check(options.size() == 1 and options[0][0] == "Test errand  (new)", "...offered when you talk to him")
			options[0][1].call()
			finish_talk()
			check(pick("Sure"), "his offer: Sure")
		150:
			check(status("test_errand") == "active", "accepted")
			check(q.talk_options(main.chief).size() == 1, "you've a plank (the story's reward): the delivery's on")
			money_before = p.money
			var planks: int = p.inventory.count("planks")
			q.talk_options(main.chief)[0][1].call()
			finish_talk()
			check(p.inventory.count("planks") == planks - 1, "handed over: one plank less")
		170:
			check(status("test_errand") == "done" and p.money == money_before + 20, "delivered: done, $20")
			q.add_quest(timed())
			check(status("test_timed") == "active", "the timed quest starts")
			main.day_night.hour += 1.5
		200:
			check(status("test_timed") == "failed", "an hour and a half later: failed, out of time (%s)" % status("test_timed"))
			print("FAILS: %d" % fails)
			return true
	return false
