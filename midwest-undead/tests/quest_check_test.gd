extends SceneTree
## The quest checks (quests/quest_check.gd, Map Tools' Check quests): the story
## and the example quest on a test map with every marker and person they need
## (HOW_TO_MAP.md, section 12) have nothing wrong. A quest made wrong on
## purpose has each of its mistakes found (a survivor with no spot on the map
## counts as nobody; one with a spot is someone), and so do a quest marker with
## no id and two with one.
const TestMap := preload("res://tests/support/test_map.gd")
const QuestCheck := preload("res://quests/quest_check.gd")
var fails := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func _initialize() -> void:
	var map := TestMap.begin()
	TestMap.base_camp(map, Vector3(0, 0, 20))
	TestMap.person(map, "chief", Vector3(3, 0.1, 22))
	TestMap.person(map, "quartermaster", Vector3(-3, 0.1, 22))
	TestMap.person(map, "woodworker", Vector3(0, 0.1, -200), true)
	TestMap.quest_marker(map, "station", "area", Vector3(0, 0, 20)).radius = 75.0
	TestMap.quest_marker(map, "safe_house", "area", Vector3(-200, 0, 60))
	TestMap.quest_marker(map, "wagon", "point", Vector3(12, 0, 34))
	TestMap.quest_marker(map, "wagon_trader", "point", Vector3(9, 0.1, 34))
	TestMap.quest_marker(map, "bandit_camp", "area", Vector3(0, 0, -200))
	TestMap.quest_marker(map, "woodworker_home", "point", Vector3(-8, 0.1, 30))
	TestMap.quest_marker(map, "gas_station", "area", Vector3(-200, 0, 90))
	TestMap.spawn_point(map, "survivor", Vector3(40, 0.1, 40), "Priya Raman") # (and nobody's spot for Dale)
	var example: Array[Quest] = [load("res://quests/examples/medicine_run.tres")]
	var found := QuestCheck.check(map, example)
	check(found.is_empty(), "the story and the example, with everything they need: nothing wrong %s" % [found])

	TestMap.quest_marker(map, "", "point", Vector3(0, 0, 50))
	TestMap.quest_marker(map, "station", "point", Vector3(0, 0, 60))
	var quests: Array[Quest] = [broken()]
	found = QuestCheck.check(map, quests)
	for line in found:
		print("    " + line)
	for expected: Array in [
		["map: quest marker", "has no Marker Id"],
		["map: quest marker", "another quest marker is \"station\" too"],
		["test_broken:", "Giver: nobody is \"nobody_here\""],
		["test_broken:", "has a Giver but no Offer"],
		["stage go > objective 1", "no quest marker \"nowhere\""],
		["stage go > objective radio", "quest marker \"station\" is an area one; it has to be a usable one"],
		["stage go > objective 3", "\"dragon\" isn't a zombie kind"],
		["stage go > objective 4", "\"unobtainium\" isn't an item"],
		["stage go > objective 5", "\"wagon\" is a point one; it has to be an area one"],
		["stage go > objective 6", "event \"zombie_kiled\": nothing reports that"],
		["stage go > objective 6", "Leads To, but its stage finishes when all are done"],
		["stage go > objective 6", "Leads To \"elsewhere\" isn't one of the quest's stages"],
		["stage go > objective 7", "Reached Stage \"nope\" isn't one of westside_safe_house's stages"],
		["stage go > objective 7", "there's no quest \"no_such_quest\""],
		["stage go > objective 7", "nobody is \"dale_hutchins\""],
		["stage go", "Next \"zzz\" isn't one of the quest's stages"],
		["stage go", "Spawn Person's person file has no id"],
		["stage 2", "another stage is \"go\" too"],
		["stage lost", "nothing leads to it"],
		["stage 2: nothing leads to it"],
		["objective 1 > Dialogue", "reply \"Go on\": Next \"missing\" isn't one of its nodes"],
		["stage lost > objective 1 > Dialogue", "starting at node \"start\", it never gets to an end"],
	]:
		check(found.any(func(line: String) -> bool: return expected.all(func(bit: String) -> bool: return line.contains(bit))),
				"found: %s" % " ... ".join(expected))
	check(not found.any(func(line: String) -> bool: return line.contains("priya_raman")),
			"a survivor with a spot on the map is someone quests can name")
	check(not found.any(func(line: String) -> bool: return line.begins_with("westside_safe_house") or line.begins_with("medicine_run")),
			"...and still nothing about the story")
	map.free()
	print("FAILS: %d" % fails)
	quit()

func objective(script: Script, props: Dictionary) -> QuestObjective:
	var o: QuestObjective = script.new()
	for k in props:
		o.set(k, props[k])
	return o

func stage(id: String, objectives: Array) -> QuestStage:
	var s := QuestStage.new()
	s.id = id
	s.objectives.assign(objectives)
	return s

## A quest with a mistake in nearly everything.
func broken() -> Quest:
	var quest := Quest.new()
	quest.id = "test_broken"; quest.title = "Broken"; quest.giver = "nobody_here" # (and no offer)
	var reached := ConditionQuest.new(); reached.quest = "westside_safe_house"; reached.reached_stage = "nope"
	var missing := ConditionQuest.new(); missing.quest = "no_such_quest"
	var dale := ConditionPersonAlive.new(); dale.npc = "dale_hutchins" # (no spot on the map: never there)
	var priya := ConditionPersonAlive.new(); priya.npc = "priya_raman"
	var go := stage("go", [
		objective(ObjectiveGoTo, {"marker": "nowhere"}),
		objective(ObjectiveUse, {"id": "radio", "marker": "station"}),
		objective(ObjectiveKill, {"zombie_kind": "dragon"}),
		objective(ObjectiveCollect, {"item": "unobtainium"}),
		objective(ObjectiveSurvive, {"stay_in": "wagon"}),
		objective(ObjectiveEvent, {"event": "zombie_kiled", "leads_to": "elsewhere"}),
		objective(ObjectiveWaitFor, {"conditions": [reached, missing, dale, priya] as Array[QuestCondition]}),
	])
	go.next = "zzz"
	var nameless := ActionSpawnPerson.new(); nameless.person = PersonData.new(); nameless.at = "wagon"
	go.on_start.assign([nameless])
	# A reply to a node that isn't there.
	var hello := QuestDialogueNode.new(); hello.lines.assign(["Hi."])
	var on := QuestReply.new(); on.text = "Go on"; on.next = "missing"
	hello.replies.assign([on])
	var talk := QuestDialogue.new(); talk.nodes.assign([hello])
	# A conversation that only loops, or declines.
	var loop := QuestDialogueNode.new(); loop.lines.assign(["Again?"])
	var again := QuestReply.new(); again.text = "Again"; again.next = "start"
	var no := QuestReply.new(); no.text = "No"; no.action = "decline"
	loop.replies.assign([again, no])
	var stuck := QuestDialogue.new(); stuck.nodes.assign([loop])
	quest.stages.assign([
		go,
		stage("go", [objective(ObjectiveTalkTo, {"npc": "chief", "dialogue": talk})]),
		stage("lost", [objective(ObjectiveTalkTo, {"npc": "chief", "dialogue": stuck})]),
	])
	return quest
