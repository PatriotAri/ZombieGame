extends SceneTree
## The quest debug panel (ui/quest_debug.gd, F4) and what it calls in the quest
## manager: F4 opens it (the game paused); a quest of three stages started by
## hand, an objective counted as done (on to the next stage), put at its last
## stage, finished (paid), then reset (it starts again, being one that starts
## by itself); a flag set and an item given from the panel; Go there takes you
## to a quest marker and closes it, the game going again (and the quest, its
## flag set, starting again).
const TestMap := preload("res://tests/support/test_map.gd")
var main: Node
var q: Node
var p: Node
var panel: Node
var f := 0
var fails := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	preload("res://quests/quest_manager.gd").folders = [] # only the quest made here
	var map := TestMap.begin()
	TestMap.quest_marker(map, "farm", "area", Vector3(60, 0, 0)).radius = 8.0
	TestMap.quest_marker(map, "well", "point", Vector3(-30, 0, 0))
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = TestMap.finish(map)
	root.add_child(main)

func quest() -> Quest:
	var quest := Quest.new()
	quest.id = "test_debug"; quest.title = "Debug"; quest.reward_money = 7
	var stages: Array[QuestStage] = []
	for id in ["a", "b", "c"]:
		var s := QuestStage.new(); s.id = id
		var go := ObjectiveGoTo.new(); go.marker = "well" if id == "c" else "farm"; go.text = "Stage " + id
		s.objectives.assign([go])
		stages.append(s)
	quest.stages = stages
	var after := ConditionFlag.new(); after.flag = "debug_go" # (only once the panel sets it)
	quest.available_when.assign([after])
	return quest

func press(text: String) -> void:
	for b in panel.find_children("*", "Button", true, false):
		if b.text == text and not b is OptionButton:
			b.pressed.emit()
			return
	check(false, "no button " + text)

func stage() -> String:
	return q._state["test_debug"]["stage"]

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		3:
			q = main.quests
			p = main.player
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			panel = main.get_children().filter(func(n: Node) -> bool: return n.get_script() == preload("res://ui/quest_debug.gd"))[0]
			q.add_quest(quest())
			check(q.status_of("test_debug") == "locked", "the quest is locked (its flag isn't set)")
			key(KEY_F4)
		5:
			check(panel.visible and paused, "F4 opens the panel, and pauses the game")
			check(panel._quest() == "test_debug", "...with the quest picked")
			press("Start")
			check(q.status_of("test_debug") == "active" and stage() == "a", "Start: going, at its first stage (locked or not)")
			press("Count as done")
			check(stage() == "b", "Count as done: the objective's done, on to the next stage (%s)" % stage())
			panel._stages.select(2)
			press("Go to stage")
			check(stage() == "c" and panel._summary.text.contains("Stage: c"), "Go to stage: at the last (%s)" % stage())
			var money: int = p.money
			press("Finish")
			check(q.status_of("test_debug") == "done" and p.money == money + 7, "Finish: done and paid ($%d)" % (p.money - money))
			press("Reset")
			check(q.status_of("test_debug") == "locked", "Reset: locked again (%s)" % q.status_of("test_debug"))
			panel._flag_name.text = "debug_go"
			press("Set")
			check(q.flag("debug_go") == 1 and panel._flags.text.contains("debug_go = 1"), "a flag set from the panel")
			check(q.status_of("test_debug") == "locked", "...the quest waiting for the game to go again (its time's stopped)")
			var planks: int = p.inventory.count("planks")
			for i in panel._items.item_count:
				if panel._items.get_item_metadata(i) == "planks":
					panel._items.select(i)
			panel._item_count.value = 3
			press("Give")
			check(p.inventory.count("planks") == planks + 3, "Give: three planks")
			for i in panel._markers.item_count:
				if panel._markers.get_item_text(i) == "farm":
					panel._markers.select(i)
			press("Go there")
			check(not panel.visible and not paused, "Go there closes the panel, the game going again")
		100: # (quests unlock once a second)
			check(p.global_position.distance_to(q.world.marker("farm").global_position) < 3.0, "...and you're at the farm")
			check(q.status_of("test_debug") == "active", "the flag's set: the quest, one that starts by itself, begins again")
			check(stage() == "c", "...and you're at the farm, so stages a and b (both the farm) are done at once (%s)" % stage())
			print("FAILS: %d" % fails)
			return true
	return false
